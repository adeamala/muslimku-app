import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muslimku/core/storage/local_store.dart';
import 'package:muslimku/core/utils/arabic_text.dart';
import 'package:muslimku/features/quran/application/quran_progress_provider.dart';
import 'package:muslimku/features/quran/presentation/reader/reader_controls.dart';
import 'package:muslimku/features/reading/application/reading_settings_provider.dart';
import 'package:muslimku/shared/widgets/senja/senja.dart';

import '../../../support/fake_quran_api.dart';
import 'reader_harness.dart';

Finder _switchOf(String label) => find.descendant(
  of: find.widgetWithText(ReaderToggleRow, label),
  matching: find.byType(ReaderSwitch),
);

bool _isAsset(Widget w, String name) =>
    w is Image &&
    w.image is AssetImage &&
    (w.image as AssetImage).assetName == name;

void main() {
  testWidgets('shows the surah banner, bismillah and ayat', (tester) async {
    final h = await pumpReader(tester);

    expect(find.text('Al-Baqarah'), findsNWidgets(2), reason: 'bar + banner');
    expect(find.text('Sapi · Madaniyyah · 40 ayat'), findsOneWidget);
    expect(find.text('Putar murottal'), findsOneWidget);
    expect(find.text('Tafsir'), findsOneWidget);
    expect(find.text(bismillah), findsOneWidget);
    expect(find.text('الۤمّۤۚ'), findsOneWidget);
    expect(find.text('latin 2:1'), findsOneWidget);
    expect(find.text('arti 2:1'), findsOneWidget);
    expect(find.text('Juz 1 · Hal. 2'), findsOneWidget);
    expect(find.byTooltip('Putar ayat 1'), findsOneWidget);
    expect(find.byTooltip('Tampilan bacaan'), findsOneWidget);
    expect(find.byTooltip('Lompat ke ayat'), findsOneWidget);
    expect(
      h.api.requests,
      containsAll(['quran/ayat/2/1-30', 'quran/ayat/2/31-40']),
    );

    await tester.tap(find.text('Tafsir'));
    await settleReader(tester);
    expect(find.text('Tafsir Al-Baqarah'), findsOneWidget);
    expect(find.text('Tafsir 2'), findsOneWidget);
    await closeReader(tester);
  });

  testWidgets('the reading sheet hides latin and changes theme live', (
    tester,
  ) async {
    final h = await pumpReader(tester);
    await tester.tap(find.byTooltip('Tampilan bacaan'));
    await settleReader(tester);
    expect(find.text('Tampilan bacaan'), findsOneWidget);
    expect(find.text('Ukuran huruf Arab'), findsOneWidget);
    expect(find.text('28'), findsOneWidget);
    // "Tajwid berwarna" is a real toggle since 1.5.0 (no "segera" tag).
    expect(find.text('segera'), findsNothing);
    expect(find.text('Tajwid berwarna'), findsOneWidget);

    await tester.tap(_switchOf('Latin'));
    await settleReader(tester);
    expect(h.container.read(readingSettingsProvider).showLatin, isFalse);
    expect(find.text('latin 2:1'), findsNothing, reason: 'applies live');
    expect(find.text('arti 2:1'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Tema Senja'));
    await settleReader(tester);
    expect(h.container.read(readingSettingsProvider).theme, ReadingTheme.senja);

    await tester.tap(find.text('Atur ulang'));
    await settleReader(tester);
    final reset = h.container.read(readingSettingsProvider);
    expect((reset.showLatin, reset.theme), (true, ReadingTheme.terang));

    await tester.tapAt(const Offset(195, 40)); // the scrim closes the sheet
    await settleReader(tester);
    expect(find.text('Ukuran huruf Arab'), findsNothing);
    expect(find.text('latin 2:1'), findsOneWidget);
    await closeReader(tester);
  });

  testWidgets('Malam draws the Mihrab Emas page with the night palette', (
    tester,
  ) async {
    final h = await pumpReader(tester);
    h.container
        .read(readingSettingsProvider.notifier)
        .setTheme(ReadingTheme.malam);
    await settleReader(tester);

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, ReadingPalette.malam.background);
    expect(
      find.byWidgetPredicate((w) => _isAsset(w, 'images/3d/night_arch.webp')),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (w) => _isAsset(w, 'images/3d/night_lantern.webp'),
      ),
      findsNWidgets(4), // two lanterns, each with a blurred glow copy
    );
    expect(find.text('Al-Baqarah · Sapi'), findsOneWidget);
    expect(find.text('Madaniyyah · 40 ayat'), findsOneWidget);
    expect(find.text('Putar murottal'), findsNothing, reason: 'no banner');
    expect(
      tester.widgetList<OctagramBadge>(find.byType(OctagramBadge)),
      everyElement(isA<OctagramBadge>().having((b) => b.gold, 'gold', true)),
    );
    final arabic = tester.widget<Text>(find.text('الۤمّۤۚ'));
    expect(arabic.style!.color, ReadingPalette.malam.arabic);
    expect(
      find.text('Mode malam otomatis · setelah Maghrib'),
      findsNothing,
      reason: 'chosen by hand, not by the Maghrib switch',
    );
    await closeReader(tester);
  });

  testWidgets('after Maghrib the night page says it switched by itself', (
    tester,
  ) async {
    await pumpReader(tester, now: DateTime(2026, 10, 25, 19));
    expect(find.text('Mode malam otomatis · setelah Maghrib'), findsOneWidget);
    await closeReader(tester);
  });

  testWidgets('offline and never saved shows how to get the surah', (
    tester,
  ) async {
    final store = MemoryLocalStore();
    await saveSurahList(store);
    final api = FakeQuranApi(offline: true);
    await pumpReader(tester, api: api, store: store);

    expect(find.text('Surat ini belum tersimpan'), findsOneWidget);
    expect(
      find.text(
        'Buka sekali saat ada internet. Setelah itu Al-Baqarah bisa dibaca '
        'kapan saja, tanpa kuota.',
      ),
      findsOneWidget,
    );
    expect(find.text('Al-Baqarah'), findsOneWidget);
    expect(find.text('Sapi · 40 ayat'), findsOneWidget);
    expect(find.text('Buka surat yang tersimpan'), findsOneWidget);
    expect(
      find.text('Unduh semua surat di Pengaturan › Data offline'),
      findsOneWidget,
    );

    api.offline = false;
    await tester.tap(find.text('Coba lagi'));
    await settleReader(tester);
    expect(find.text('Surat ini belum tersimpan'), findsNothing);
    expect(find.text('arti 2:1'), findsOneWidget);
    await closeReader(tester);
  });

  testWidgets('opens at an ayah, saves the place and marks a finished juz', (
    tester,
  ) async {
    final h = await pumpReader(tester, initialAyah: 30);
    expect(find.text('Juz 2 · Hal. 5'), findsOneWidget);
    expect(find.text('arti 2:30'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1100));
    final last = h.container.read(lastReadProvider)!;
    expect(
      (last.surah, last.ayah, last.surahName, last.juz, last.page),
      (2, 30, 'Al-Baqarah', 2, 5),
    );
    expect(h.container.read(khatamProvider), isEmpty);

    await tester.tap(find.byTooltip('Lompat ke ayat'));
    await settleReader(tester);
    await tester.enterText(find.byType(TextField), '41');
    await tester.tap(find.text('Buka'));
    await settleReader(tester);
    expect(find.text('Pilih nomor 1–40'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '40');
    await tester.tap(find.text('Buka'));
    await settleReader(tester);
    expect(find.text('arti 2:40'), findsOneWidget);
    expect(h.container.read(khatamProvider), {2}, reason: 'juz 2 ends at 40');
    await closeReader(tester);
  });

  testWidgets('leaving before the debounce still saves the place', (
    tester,
  ) async {
    final h = await pumpReader(tester, initialAyah: 12, launcher: true);
    await tester.tap(find.text('Buka surat'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('arti 2:12'), findsOneWidget);
    expect(h.container.read(lastReadProvider), isNull, reason: 'debounced');

    await tester.tap(find.byTooltip('Kembali'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();
    expect(find.text('Buka surat'), findsOneWidget);
    expect(h.container.read(lastReadProvider)?.ayah, 12);
    await closeReader(tester);
  });

  testWidgets('leaving the reader stops the murottal', (tester) async {
    final h = await pumpReader(tester, initialAyah: 12, launcher: true);
    await tester.tap(find.text('Buka surat'));
    await settleReader(tester);
    await tester.tap(find.byTooltip('Putar ayat 12'));
    await settleReader(tester);
    expect(find.text('Al-Baqarah · Ayat 12'), findsOneWidget);

    await tester.tap(find.byTooltip('Kembali'));
    await settleReader(tester);
    await tester.pump(const Duration(milliseconds: 300)); // route + dispose
    expect(find.text('Buka surat'), findsOneWidget);
    expect(h.player.calls, containsAllInOrder(['play', 'stop', 'dispose']));
    await closeReader(tester);
  });

  testWidgets('the end of a surah leads to the next one', (tester) async {
    await pumpReader(tester, surah: 1, initialAyah: 7);
    expect(find.text(bismillah), findsNothing, reason: 'it is ayah 1 here');
    final next = find.text('Lanjut ke surat berikutnya: Al-Baqarah');
    expect(next, findsOneWidget);

    await tester.tap(next);
    await settleReader(tester);
    expect(find.text('Sapi · Madaniyyah · 40 ayat'), findsOneWidget);
    expect(find.text('Al-Fatihah'), findsNothing);
    await closeReader(tester);
  });
}
