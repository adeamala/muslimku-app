import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muslimku/core/network/api_service.dart';
import 'package:muslimku/core/storage/local_store.dart';
import 'package:muslimku/core/theme/app_theme.dart';
import 'package:muslimku/core/time/clock_provider.dart';
import 'package:muslimku/features/quran/application/quran_audio_provider.dart';
import 'package:muslimku/features/quran/data/murottal_store.dart';
import 'package:muslimku/features/quran/data/quran_repository.dart';
import 'package:muslimku/features/quran/presentation/quran_reader_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/fake_quran_api.dart';
import '../../../support/fake_quran_reader_api.dart';

/// A reader pumped at phone size with fakes for MyQuran and the audio player.
class ReaderHarness {
  ReaderHarness(this.tester, this.api, this.store, this.player, this.murottal);

  final WidgetTester tester;
  final FakeQuranApi api;
  final MemoryLocalStore store;
  final FakeMurottalPlayer player;

  /// Murottal files "on the phone" (Murottal offline).
  final MemoryMurottalStore murottal;
  String? clipboard;

  ProviderContainer get container =>
      ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));
}

/// 10:00, so "Malam otomatis setelah Maghrib" stays off unless a test wants it.
final morning = DateTime(2026, 10, 25, 10);

/// Pumps [QuranReaderScreen] at 390×844 with animations off.
Future<ReaderHarness> pumpReader(
  WidgetTester tester, {
  int surah = 2,
  int initialAyah = 1,
  FakeQuranApi? api,
  MemoryLocalStore? store,
  MemoryMurottalStore? murottal,
  DateTime? now,
  double textScale = 1,
  Map<String, Object> prefs = const {},
  List<Override> overrides = const [],
  bool launcher = false,
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final harness = ReaderHarness(
    tester,
    api ?? FakeQuranApi(),
    store ?? MemoryLocalStore(),
    FakeMurottalPlayer(),
    murottal ?? MemoryMurottalStore(),
  );
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'Clipboard.setData') {
        harness.clipboard = (call.arguments as Map)['text'] as String?;
      }
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        apiServiceProvider.overrideWithValue(harness.api),
        localStoreProvider.overrideWithValue(harness.store),
        clockProvider.overrideWith((ref) => Stream.value(now ?? morning)),
        murottalPlayerFactoryProvider.overrideWithValue(() => harness.player),
        murottalStoreProvider.overrideWithValue(harness.murottal),
        ...overrides,
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            disableAnimations: true,
            textScaler: TextScaler.linear(textScale),
          ),
          child: child!,
        ),
        home: launcher
            ? Builder(
                builder: (context) => Scaffold(
                  body: Center(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => QuranReaderScreen(
                            surahNumber: surah,
                            initialAyah: initialAyah,
                          ),
                        ),
                      ),
                      child: const Text('Buka surat'),
                    ),
                  ),
                ),
              )
            : QuranReaderScreen(surahNumber: surah, initialAyah: initialAyah),
      ),
    ),
  );
  await settleReader(tester);
  return harness;
}

Future<void> settleReader(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Saves the surah list as if it had been opened online before.
Future<void> saveSurahList(MemoryLocalStore store) =>
    store.writeJson(QuranRepository.surahListKey, {
      'savedAt': DateTime.now().toIso8601String(),
      'data': [FakeQuranApi.surahJson(1), FakeQuranApi.surahJson(2)],
    });

/// Closes the reader so its last save and audio stop run inside the test.
Future<void> closeReader(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 2));
}
