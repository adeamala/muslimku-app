import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:muslimku/core/storage/local_store.dart';
import 'package:muslimku/shared/widgets/senja/senja.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/fake_quran_api.dart';
import 'pump_quran.dart';

Future<void> _openTab(WidgetTester tester, String label) async {
  final segment = find.descendant(
    of: find.byType(SenjaSegmented),
    matching: find.textContaining(label, findRichText: true),
  );
  await tester.ensureVisible(segment);
  await tester.pump();
  await tester.tap(segment);
  await settle(tester);
}

final _marks = bookmarksJson([
  (2, 5, 'Al-Baqarah', 'arti 2:5', '2026-10-20T08:00:00.000'),
  (
    67,
    1,
    'Al-Mulk',
    'Mahasuci Allah yang menguasai segala kerajaan',
    '2026-10-24T08:00:00.000',
  ),
]);

void main() {
  setUpAll(() => initializeDateFormatting('id_ID', null));
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Juz tab shows khatam progress and opens a juz at its start', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'quran_khatam_juz': ['1'],
      'quran_last_read': lastReadJson(ayah: 30, juz: 2),
    });
    final semantics = tester.ensureSemantics();
    await pumpQuran(tester, api: FakeQuranApi());
    await _openTab(tester, 'Juz');

    expect(find.text('Progres khatam'), findsOneWidget);
    expect(find.text('1 dari 30 juz'), findsOneWidget);
    expect(
      find.textContaining('Juz 2 · Al-Baqarah ayat 30', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('Juz 1'), findsOneWidget);
    expect(find.text('Al-Baqarah 26 –\nAl-Baqarah 40'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'^Juz 1, selesai')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'^Juz 2, selesai')), findsNothing);
    semantics.dispose();

    await tester.tap(find.text('Juz 2'));
    await settle(tester);
    expect(openedReader(tester), (2, 26));
  });

  testWidgets('long-pressing a juz marks it finished, with undo', (
    tester,
  ) async {
    await pumpQuran(tester, api: FakeQuranApi());
    await _openTab(tester, 'Juz');
    expect(find.text('0 dari 30 juz'), findsOneWidget);
    expect(
      find.textContaining('Sedang dibaca', findRichText: true),
      findsNothing,
    );

    await tester.longPress(find.text('Juz 2'));
    await settle(tester);
    expect(find.text('1 dari 30 juz'), findsOneWidget);
    expect(find.text('Juz 2 ditandai selesai'), findsOneWidget);

    await tester.tap(find.text('Urungkan'));
    await settle(tester);
    expect(find.text('0 dari 30 juz'), findsOneWidget);
  });

  testWidgets('Ditandai shows a friendly empty state', (tester) async {
    await pumpQuran(tester, api: FakeQuranApi());
    await _openTab(tester, 'Ditandai');
    expect(find.text('Belum ada ayat yang ditandai'), findsOneWidget);
    expect(
      find.text('Ketuk ikon penanda di halaman baca untuk menyimpan ayat.'),
      findsOneWidget,
    );
  });

  testWidgets('Ditandai lists marks newest first; removing can be undone', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'quran_bookmarks': _marks});
    await pumpQuran(tester, api: FakeQuranApi());
    expect(find.text('Ditandai 2', findRichText: true), findsOneWidget);
    await _openTab(tester, 'Ditandai');

    final mulk = find.text('Al-Mulk · Ayat 1');
    final baqarah = find.text('Al-Baqarah · Ayat 5');
    expect(mulk, findsOneWidget);
    expect(tester.getTopLeft(mulk).dy, lessThan(tester.getTopLeft(baqarah).dy));
    expect(
      find.text('Mahasuci Allah yang menguasai segala kerajaan'),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip('Hapus tanda').first);
    await settle(tester);
    expect(mulk, findsNothing);
    expect(find.text('Ditandai 1', findRichText: true), findsOneWidget);

    await tester.tap(find.text('Urungkan'));
    await settle(tester);
    expect(mulk, findsOneWidget);
    expect(
      tester.getTopLeft(mulk).dy,
      lessThan(tester.getTopLeft(baqarah).dy),
      reason: 'undo restores the original place',
    );

    await tester.tap(baqarah);
    await settle(tester);
    expect(openedReader(tester), (2, 5));
  });

  testWidgets('every tab fits at 130 % text size, also offline', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'quran_khatam_juz': ['1', '2'],
      'quran_last_read': lastReadJson(),
      'quran_bookmarks': _marks,
    });
    final store = MemoryLocalStore();
    saveSurahList(store);
    saveFatihah(store);
    await pumpQuran(
      tester,
      api: FakeQuranApi(offline: true),
      store: store,
      textScale: 1.3,
    );
    expect(tester.takeException(), isNull);
    expect(find.text('LANJUTKAN MEMBACA'), findsOneWidget);

    await _openTab(tester, 'Juz');
    expect(tester.takeException(), isNull);
    await _openTab(tester, 'Tema');
    expect(tester.takeException(), isNull);
    // Four segments: no label may be cut even at 130 % (the labels are
    // Text.rich inside a FittedBox, so look at every paragraph in the bar).
    final bar = find.byType(SenjaSegmented);
    final paragraphs = find.descendant(
      of: bar,
      matching: find.byType(RichText),
    );
    expect(paragraphs, findsNWidgets(4));
    for (final element in paragraphs.evaluate()) {
      final paragraph = element.renderObject! as RenderParagraph;
      expect(paragraph.didExceedMaxLines, isFalse);
    }
    await _openTab(tester, 'Ditandai');
    expect(tester.takeException(), isNull);
    expect(find.text('Al-Mulk · Ayat 1'), findsOneWidget);
  });
}
