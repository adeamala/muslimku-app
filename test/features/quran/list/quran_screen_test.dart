import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:muslimku/core/storage/local_store.dart';
import 'package:muslimku/shared/widgets/senja/senja.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/fake_quran_api.dart';
import 'pump_quran.dart';

SenjaListRow _row(WidgetTester tester, String title) =>
    tester.widget(find.widgetWithText(SenjaListRow, title));

/// 30 surahs (so the list scrolls), and every `quran/ayat/juz/<n>` request
/// waits for [gate], so the download stays running.
class _GatedJuzApi extends FakeQuranApi {
  final gate = Completer<void>();

  @override
  Future<List<Map<String, dynamic>>?> getAllSurat() async {
    await super.getAllSurat();
    return [
      for (var n = 1; n <= 30; n++)
        n <= 2
            ? FakeQuranApi.surahJson(n)
            : {
                'number': '$n',
                'name_id': 'Surat $n',
                'name_short': 'سورة',
                'translation_id': 'Arti $n',
                'revelation_id': 'Makkiyyah',
                'number_of_verses': '10',
              },
    ];
  }

  @override
  Future<dynamic> getJson(String path) async {
    if (path.startsWith('quran/ayat/juz/')) await gate.future;
    return super.getJson(path);
  }
}

void main() {
  setUpAll(() => initializeDateFormatting('id_ID', null));
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('lists surahs with meaning, Arabic name and ayat count', (
    tester,
  ) async {
    final api = FakeQuranApi();
    await pumpQuran(tester, api: api);

    expect(find.text('Al-Fatihah'), findsOneWidget);
    expect(find.text('Pembukaan · Makkiyyah'), findsOneWidget);
    expect(find.text('الفاتحة'), findsOneWidget);
    expect(find.text('7 ayat'), findsOneWidget);
    expect(find.text('Sapi · Madaniyyah'), findsOneWidget);
    expect(find.text('40 ayat'), findsOneWidget);
    expect(find.text('LANJUTKAN MEMBACA'), findsNothing);
    expect(find.byType(OfflineBanner), findsNothing);
    expect(find.text('Simpan semua surat di HP (±6 MB)'), findsOneWidget);
    expect(api.requests, ['quran/surat/semua']);

    String? fontOf(String text) =>
        DefaultTextStyle.of(tester.element(find.text(text))).style.fontFamily;
    expect(
      fontOf('Simpan semua surat di HP (±6 MB)'),
      'PlusJakartaSans',
      reason: 'button labels must not fall back to Roboto',
    );
  });

  testWidgets('search finds surahs by name, number or meaning', (tester) async {
    await pumpQuran(tester, api: FakeQuranApi());
    final field = find.byType(TextField);

    await tester.enterText(field, 'sapi');
    await settle(tester);
    expect(find.text('Al-Baqarah'), findsOneWidget);
    expect(find.text('Al-Fatihah'), findsNothing);

    await tester.enterText(field, 'al fatihah');
    await settle(tester);
    expect(find.text('Al-Fatihah'), findsOneWidget);
    expect(find.text('Al-Baqarah'), findsNothing);

    await tester.enterText(field, '2');
    await settle(tester);
    expect(find.text('Al-Baqarah'), findsOneWidget);
    expect(find.text('Al-Fatihah'), findsNothing);

    await tester.enterText(field, 'zzz');
    await settle(tester);
    expect(find.text('Tidak ada surat yang cocok'), findsOneWidget);
    expect(
      DefaultTextStyle.of(
        tester.element(find.text('Hapus pencarian')),
      ).style.fontFamily,
      'PlusJakartaSans',
    );
    await tester.tap(find.text('Hapus pencarian'));
    await settle(tester);
    expect(find.text('Al-Fatihah'), findsOneWidget);
    expect(find.text('Al-Baqarah'), findsOneWidget);
  });

  testWidgets('the filter sheet keeps only Madaniyyah surahs', (tester) async {
    await pumpQuran(tester, api: FakeQuranApi());
    SenjaSearchAction action() => tester.widget(find.byType(SenjaSearchAction));
    expect(action().active, isFalse);

    await tester.tap(find.byTooltip('Saring surat'));
    await settle(tester);
    await tester.tap(find.text('Madaniyyah'));
    await settle(tester);

    expect(find.text('Al-Baqarah'), findsOneWidget);
    expect(find.text('Al-Fatihah'), findsNothing);
    expect(action().active, isTrue);
  });

  testWidgets('Lanjutkan membaca opens the reader at the last ayah', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'quran_last_read': lastReadJson()});
    await pumpQuran(tester, api: FakeQuranApi());

    expect(find.text('LANJUTKAN MEMBACA'), findsOneWidget);
    expect(find.text('Ayat 12 dari 40 · Juz 1 · Hal. 3'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'fat');
    await settle(tester);
    expect(
      find.text('LANJUTKAN MEMBACA'),
      findsNothing,
      reason: 'results come right under the search field',
    );
    await tester.enterText(find.byType(TextField), '');
    await settle(tester);

    await tester.tap(find.byTooltip('Lanjutkan membaca'));
    await settle(tester);
    expect(openedReader(tester), (2, 12));
  });

  testWidgets('tapping a surah opens the reader at its first ayah', (
    tester,
  ) async {
    await pumpQuran(tester, api: FakeQuranApi());
    await tester.tap(find.text('Al-Baqarah'));
    await settle(tester);
    expect(openedReader(tester), (2, 1));
  });

  testWidgets('saving all surahs from the list end shows the progress card', (
    tester,
  ) async {
    final api = _GatedJuzApi();
    await pumpQuran(tester, api: api, animations: true);
    final footer = find.text('Simpan semua surat di HP (±6 MB)');
    await tester.scrollUntilVisible(
      footer,
      300,
      scrollable: find
          .descendant(
            of: find.byType(CustomScrollView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.ensureVisible(footer);
    await settle(tester);
    final list = tester.widget<CustomScrollView>(find.byType(CustomScrollView));
    expect(list.controller!.offset, greaterThan(0));

    await tester.tap(footer);
    await settle(tester);
    expect(list.controller!.offset, 0, reason: 'back up to the card');
    expect(find.text("Simpan Al-Qur'an di HP"), findsOneWidget);
    expect(find.text('0/114'), findsOneWidget);

    await tester.tap(find.text('Batal'));
    await settle(tester);
    expect(find.text("Simpan Al-Qur'an di HP"), findsNothing);
    expect(footer, findsNothing, reason: 'the list is scrolled to the top');
    api.gate.complete();
    await settle(tester);
  });

  testWidgets('offline with a saved list: banner, saved marks, dimmed rows', (
    tester,
  ) async {
    final store = MemoryLocalStore();
    saveSurahList(store);
    saveFatihah(store);
    final semantics = tester.ensureSemantics();
    await pumpQuran(tester, api: FakeQuranApi(offline: true), store: store);

    expect(find.byType(OfflineBanner), findsOneWidget);
    expect(
      find.text('Surat yang sudah tersimpan tetap bisa dibaca.'),
      findsOneWidget,
    );
    expect(
      find.byTooltip('Coba lagi'),
      findsNothing,
      reason: 'pull to refresh',
    );
    expect(find.text("Simpan Al-Qur'an di HP"), findsOneWidget);
    expect(find.text('1/114'), findsOneWidget);
    expect(
      tester.getSemantics(find.text('Lanjutkan')),
      containsSemantics(label: 'Lanjutkan', isButton: true, hasTapAction: true),
    );
    expect(_row(tester, 'Al-Fatihah').dimmed, isFalse);
    expect(_row(tester, 'Al-Baqarah').dimmed, isTrue);
    expect(find.bySemanticsLabel(RegExp('Tersimpan di HP')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Belum tersimpan')), findsOneWidget);
    expect(find.text('Simpan semua surat di HP (±6 MB)'), findsNothing);
    semantics.dispose();
  });

  testWidgets('pulling to refresh offline shows the banner, online clears it', (
    tester,
  ) async {
    final api = FakeQuranApi();
    await pumpQuran(tester, api: api);
    expect(find.byType(OfflineBanner), findsNothing);

    api.offline = true;
    await tester.fling(find.text('Al-Fatihah'), const Offset(0, 400), 1500);
    await settle(tester, 30);
    expect(find.byType(OfflineBanner), findsOneWidget);
    expect(find.text('Al-Fatihah'), findsOneWidget, reason: 'saved list');
    expect(_row(tester, 'Al-Fatihah').dimmed, isTrue);

    api.offline = false;
    await tester.fling(find.byType(OfflineBanner), const Offset(0, 400), 1500);
    await settle(tester, 30);
    expect(find.byType(OfflineBanner), findsNothing);
    expect(_row(tester, 'Al-Fatihah').dimmed, isFalse);
    expect(api.requests.where((r) => r == 'quran/surat/semua'), hasLength(3));
  });

  testWidgets('an error without a saved list offers Coba lagi', (tester) async {
    final api = FakeQuranApi(offline: true);
    await pumpQuran(tester, api: api);
    expect(find.text('Daftar surat belum bisa dimuat'), findsOneWidget);
    expect(find.text('Periksa internet lalu coba lagi.'), findsOneWidget);

    api.offline = false;
    await tester.tap(find.text('Coba lagi'));
    await settle(tester);
    expect(find.text('Al-Fatihah'), findsOneWidget);
  });
}
