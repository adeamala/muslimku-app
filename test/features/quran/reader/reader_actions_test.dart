import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muslimku/features/quran/application/quran_audio_provider.dart';
import 'package:muslimku/features/quran/application/quran_progress_provider.dart';
import 'package:muslimku/features/quran/presentation/quran_reader_screen.dart';
import 'package:muslimku/features/quran/presentation/reader/reader_controls.dart';
import 'package:muslimku/features/quran/presentation/reader/share_ayah_sheet.dart';
import 'package:muslimku/features/quran/presentation/reader/share_card.dart';
import 'package:muslimku/features/reading/application/reading_settings_provider.dart';

import 'reader_harness.dart';

Finder _switchOf(String label) => find.descendant(
  of: find.widgetWithText(ReaderToggleRow, label),
  matching: find.byType(ReaderSwitch),
);

void main() {
  testWidgets('murottal plays ayah by ayah in the mini player', (tester) async {
    final h = await pumpReader(tester);
    expect(find.text('Mishary Rashid Alafasy'), findsNothing);

    await tester.tap(find.text('Putar murottal'));
    await settleReader(tester);
    // Al-Baqarah 1 is ayah 8 of the Qur'an in the fake.
    expect(h.player.played, [
      'https://cdn.islamic.network/quran/audio/128/ar.alafasy/8.mp3',
    ]);
    expect(find.text('Al-Baqarah · Ayat 1'), findsOneWidget);
    expect(find.text('Mishary Rashid Alafasy'), findsOneWidget);
    expect(find.text('Sedang diputar'), findsOneWidget);
    expect(find.text('Jeda murottal'), findsOneWidget, reason: 'banner pill');
    expect(find.byTooltip('Jeda ayat 1'), findsOneWidget);

    h.player.complete();
    await settleReader(tester);
    expect(find.text('Al-Baqarah · Ayat 2'), findsOneWidget);
    expect(h.player.played.last, endsWith('/9.mp3'));

    await tester.tap(find.byTooltip('Jeda murottal'));
    await settleReader(tester);
    expect(h.container.read(quranAudioProvider).playing, isFalse);
    expect(find.text('Dijeda'), findsOneWidget);

    await tester.tap(find.byTooltip('Putar ayat 5'));
    await settleReader(tester);
    expect(find.text('Al-Baqarah · Ayat 5'), findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('ayah-5'))).dy,
      closeTo(56 + 6, 1),
      reason: 'the recited ayah is scrolled up under the app bar',
    );

    h.player.failing = {'*'};
    await tester.tap(find.byTooltip('Ayat berikutnya'));
    await settleReader(tester);
    expect(find.text('Audio butuh internet'), findsOneWidget);
    expect(find.text('Mishary Rashid Alafasy'), findsNothing);
    expect(h.container.read(quranAudioProvider).active, isFalse);

    h.player.failing = {};
    await tester.tap(find.byTooltip('Putar ayat 6'));
    await settleReader(tester);
    expect(find.text('Al-Baqarah · Ayat 6'), findsOneWidget);
    await closeReader(tester);
    expect(h.player.calls.last, 'dispose', reason: 'leaving stops the audio');
    expect(h.player.calls, contains('stop'));
  });

  testWidgets('bookmark, copy and mark the last read ayah', (tester) async {
    final h = await pumpReader(tester);
    await tester.tap(find.byTooltip('Tandai ayat 1'));
    await settleReader(tester);
    final mark = h.container.read(ayahBookmarksProvider).single;
    expect(
      (mark.surah, mark.ayah, mark.surahName, mark.snippet),
      (2, 1, 'Al-Baqarah', 'arti 2:1'),
    );
    expect(find.byTooltip('Hapus tanda ayat 1'), findsOneWidget);
    expect(find.text('Ayat 1 ditandai'), findsOneWidget);

    await tester.tap(find.byTooltip('Lainnya untuk ayat 2'));
    await settleReader(tester);
    await tester.tap(find.text('Salin ayat'));
    await settleReader(tester);
    expect(h.clipboard, 'آية 2\n\n“arti 2:2”\n\nQS Al-Baqarah 2:2');
    expect(find.text('Ayat 2 disalin'), findsOneWidget);

    expect(find.text('Terakhir dibaca'), findsNothing);
    await tester.tap(find.byTooltip('Lainnya untuk ayat 2'));
    await settleReader(tester);
    await tester.tap(find.text('Tandai terakhir dibaca'));
    await settleReader(tester);
    expect(h.container.read(lastReadProvider)!.ayah, 2);
    expect(find.text('Terakhir dibaca'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    expect(
      h.container.read(lastReadProvider)!.ayah,
      2,
      reason: 'scrolling does not overwrite a hand-made mark',
    );
    await closeReader(tester);
  });

  testWidgets('the share sheet builds the card, copies text, shares a PNG', (
    tester,
  ) async {
    (Uint8List, String)? shared;
    // The system share sheet is swapped for a recorder.
    final h = await pumpReader(
      tester,
      overrides: [
        shareAyahImageProvider.overrideWithValue(
          (png, text) async => shared = (png, text),
        ),
      ],
    );
    await tester.tap(find.byTooltip('Bagikan ayat 1'));
    await settleReader(tester);

    expect(find.text('Bagikan ayat'), findsOneWidget);
    expect(find.text('QS Al-Baqarah 2:1'), findsOneWidget);
    expect(find.text('QS AL-BAQARAH 2:1'), findsOneWidget);
    expect(find.text('“arti 2:1”'), findsOneWidget);
    final card = tester.getSize(find.byType(AyahShareCard));
    expect(card, const Size(280, 350));

    await tester.tap(_switchOf('Sertakan terjemahan'));
    await settleReader(tester);
    expect(find.text('“arti 2:1”'), findsNothing);
    await tester.tap(find.bySemanticsLabel('Template Malam'));
    await settleReader(tester);
    expect(
      tester.widget<AyahShareCard>(find.byType(AyahShareCard)).template,
      ShareTemplate.malam,
    );

    await tester.tap(find.text('Bagikan gambar'));
    for (var i = 0; i < 20 && shared == null; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
    }
    expect(shared, isNotNull);
    expect(shared!.$2, 'QS Al-Baqarah 2:1');
    expect(shared!.$1.sublist(1, 4), 'PNG'.codeUnits);

    await tester.tap(find.text('Salin teks'));
    await settleReader(tester);
    expect(h.clipboard, 'الۤمّۤۚ\n\nQS Al-Baqarah 2:1');
    expect(find.text('Bagikan ayat'), findsNothing, reason: 'sheet closed');
    expect(find.text('Teks ayat disalin'), findsOneWidget);
    await closeReader(tester);
  });

  testWidgets('nothing overflows with the phone text at 130%', (tester) async {
    final h = await pumpReader(tester, textScale: 1.3);
    await tester.tap(find.text('Putar murottal'));
    await settleReader(tester);
    expect(find.text('Al-Baqarah · Ayat 1'), findsOneWidget);

    await tester.tap(find.byTooltip('Tampilan bacaan'));
    await settleReader(tester);
    await tester.drag(find.text('Tema bacaan'), const Offset(0, -300));
    await settleReader(tester);
    await tester.tapAt(const Offset(195, 30));
    await settleReader(tester);

    await tester.tap(find.byTooltip('Bagikan ayat 1'));
    await settleReader(tester);
    expect(find.text('Bagikan gambar'), findsOneWidget);
    await tester.tap(find.byTooltip('Tutup'));
    await settleReader(tester);

    h.container
        .read(readingSettingsProvider.notifier)
        .setTheme(ReadingTheme.malam);
    await settleReader(tester);
    expect(find.text('Al-Baqarah · Sapi'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await closeReader(tester);
  });

  testWidgets('a bad ayah number still opens the reader', (tester) async {
    await pumpReader(tester, initialAyah: 99);
    expect(find.byType(QuranReaderScreen), findsOneWidget);
    expect(find.text('arti 2:40'), findsOneWidget);
    await closeReader(tester);
  });
}
