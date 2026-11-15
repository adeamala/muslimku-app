import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:muslimku/features/quran/application/murottal_download_provider.dart';
import 'package:muslimku/features/quran/data/murottal_store.dart';
import 'package:muslimku/features/quran/domain/reciters.dart';
import 'package:muslimku/features/quran/presentation/quran_reader_screen.dart';
import 'package:muslimku/features/reading/application/reading_settings_provider.dart';
import 'package:muslimku/features/settings/presentation/settings_screen.dart';

import 'reader_harness.dart';

/// Serves 1 kB per ayah; [failing] ids throw.
class FakeAudioFetcher implements AudioFetcher {
  FakeAudioFetcher({this.failing = const {}});

  final Set<int> failing;
  final List<String> fetched = [];

  @override
  Future<List<int>> fetch(String url) async {
    fetched.add(url);
    final id = int.parse(url.split('/').last.replaceAll('.mp3', ''));
    if (failing.contains(id)) throw Exception('offline');
    return List<int>.filled(1024, id % 256);
  }
}

void main() {
  late MemoryMurottalStore store;
  late FakeAudioFetcher fetcher;

  setUpAll(() => initializeDateFormatting('id_ID', null));
  setUp(() {
    store = MemoryMurottalStore();
    fetcher = FakeAudioFetcher();
  });

  List<Override> overrides() => [
    audioFetcherProvider.overrideWithValue(fetcher),
  ];

  testWidgets('the surah header offers the download; progress, then saved', (
    tester,
  ) async {
    await pumpReader(tester, surah: 1, murottal: store, overrides: overrides());
    await tester.tap(find.text('Murottal offline'));
    await tester.pumpAndSettle();
    expect(find.text('Murottal offline'), findsWidgets);
    expect(find.text('Alafasy · 7 ayat · ±1,3 MB'), findsOneWidget);
    await tester.tap(find.text('Unduh surat ini'));
    await tester.pump();
    await settleReader(tester);
    expect(find.text('Tersimpan · 7 ayat · ±7 KB'), findsOneWidget);
    expect(find.text('Hapus dari HP'), findsOneWidget);
    expect(fetcher.fetched, hasLength(7));
    expect(
      fetcher.fetched.first,
      'https://cdn.islamic.network/quran/audio/128/ar.alafasy/1.mp3',
    );
    expect(await store.has(Reciter.alafasy, 1), isTrue);
    expect(await store.has(Reciter.alafasy, 7), isTrue);
    expect(await store.has(Reciter.sudais, 1), isFalse);

    // A second download does nothing: every ayah is already there.
    await tester.tap(find.text('Hapus dari HP'));
    await tester.pumpAndSettle();
    expect(find.text('Unduh surat ini'), findsOneWidget);
    expect(await store.has(Reciter.alafasy, 1), isFalse);
  });

  testWidgets('a saved ayah plays from the phone, others from the CDN', (
    tester,
  ) async {
    await store.write(Reciter.alafasy, 1, List.filled(10, 1));
    final h = await pumpReader(
      tester,
      surah: 1,
      murottal: store,
      overrides: overrides(),
    );
    await tester.tap(find.text('Putar murottal'));
    await settleReader(tester);
    expect(h.player.played.single, startsWith('file://'));
    expect(h.player.played.single, endsWith('/ar.alafasy/1.mp3'));
    h.player.complete();
    await settleReader(tester);
    expect(
      h.player.played.last,
      'https://cdn.islamic.network/quran/audio/128/ar.alafasy/2.mp3',
    );
  });

  testWidgets('a failed ayah stops the download and keeps what came', (
    tester,
  ) async {
    fetcher = FakeAudioFetcher(failing: {4});
    await pumpReader(tester, surah: 1, murottal: store, overrides: overrides());
    await tester.tap(find.text('Murottal offline'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Unduh surat ini'));
    await tester.pump();
    await settleReader(tester);
    expect(
      find.text('Terhenti di ayat 4 · 3 dari 7 tersimpan'),
      findsOneWidget,
    );
    expect(find.text('Lanjutkan unduhan'), findsOneWidget);
    expect(await store.has(Reciter.alafasy, 3), isTrue);
    expect(await store.has(Reciter.alafasy, 4), isFalse);
    // Resuming skips the saved ayat.
    fetcher.failing.clear();
    await tester.tap(find.text('Lanjutkan unduhan'));
    await tester.pump();
    await settleReader(tester);
    expect(find.text('Tersimpan · 7 ayat · ±7 KB'), findsOneWidget);
    expect(fetcher.fetched.where((u) => u.endsWith('/1.mp3')), hasLength(1));
  });

  testWidgets('the download follows the chosen qari', (tester) async {
    await pumpReader(
      tester,
      surah: 1,
      prefs: {ReadingSettingsNotifier.reciterKey: 'sudais'},
      murottal: store,
      overrides: overrides(),
    );
    await tester.tap(find.text('Murottal offline'));
    await tester.pumpAndSettle();
    expect(find.text('As-Sudais · 7 ayat · ±1,9 MB'), findsOneWidget);
    await tester.tap(find.text('Unduh surat ini'));
    await tester.pump();
    await settleReader(tester);
    expect(fetcher.fetched.first, contains('/192/ar.abdurrahmaansudais/1.mp3'));
    expect(await store.has(Reciter.sudais, 7), isTrue);
  });

  testWidgets('Pengaturan shows the total and clears it', (tester) async {
    await store.write(Reciter.alafasy, 1, List.filled(2048, 1));
    await store.write(Reciter.sudais, 1, List.filled(1024, 1));
    await pumpReader(
      tester,
      surah: 1,
      murottal: store,
      overrides: overrides(),
      launcher: true,
    );
    await tester.tap(find.text('Buka surat'));
    await settleReader(tester);
    // Settings is reachable from the harness via a pushed route.
    final context = tester.element(find.byType(QuranReaderScreen));
    unawaited(
      Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen())),
    );
    await settleReader(tester);
    await tester.scrollUntilVisible(find.text('Murottal tersimpan'), 300);
    await tester.pumpAndSettle();
    expect(find.text('2 ayat · ±3 KB'), findsOneWidget);
    await tester.tap(find.text('Murottal tersimpan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hapus semua murottal'));
    await tester.pumpAndSettle();
    expect(await store.has(Reciter.alafasy, 1), isFalse);
    // Both the sheet and the row behind it.
    expect(find.text('Belum ada'), findsNWidgets(2));
  });

  test('MurottalStore paths are per reciter and ayah', () async {
    expect(
      MurottalStore.relativePath(Reciter.husary, 255),
      'ar.husary/255.mp3',
    );
    await store.write(Reciter.husary, 255, [1, 2, 3]);
    expect(await store.bytes(), 3);
    expect(await store.count(), 1);
    await store.deleteAll();
    expect(await store.bytes(), 0);
  });
}
