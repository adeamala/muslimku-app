import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muslimku/core/storage/content_cache.dart';
import 'package:muslimku/core/storage/local_store.dart';
import 'package:muslimku/core/utils/arabic_text.dart';
import 'package:muslimku/features/quran/data/mushaf_repository.dart';
import 'package:muslimku/features/quran/data/quran_repository.dart';
import 'package:muslimku/features/quran/domain/quran_models.dart';
import 'package:muslimku/features/quran/presentation/mushaf_page_screen.dart';
import 'package:muslimku/features/quran/presentation/quran_reader_screen.dart';

import '../../../support/fake_quran_api.dart';
import '../list/pump_quran.dart';
import 'reader_harness.dart';

void main() {
  test('arabic-indic digits for the ayah markers', () {
    expect(arabicIndic(7), '٧');
    expect(arabicIndic(286), '٢٨٦');
  });

  test('a page comes from MyQuran once, then from the phone', () async {
    final api = FakeQuranApi();
    final store = MemoryLocalStore();
    final repo = MushafRepository(
      api: api,
      store: store,
      cache: ContentCache(store),
    );
    final page = await repo.page(3);
    expect(page.data.map((a) => (a.surah, a.number)).first, (2, 10));
    expect(page.data.length, 10, reason: 'Al-Baqarah 10–19 sit on page 3');
    expect(page.fromCache, isFalse);
    api.offline = true;
    expect((await repo.page(3)).fromCache, isTrue);
    expect(api.requests.where((r) => r == 'quran/ayat/page/3'), hasLength(1));
  });

  test(
    'offline, a page is assembled from the saved surahs when whole',
    () async {
      final api = FakeQuranApi(offline: true);
      final store = MemoryLocalStore();
      saveFatihah(store);
      final repo = MushafRepository(
        api: api,
        store: store,
        cache: ContentCache(store),
      );
      // Only Al-Fatihah saved: nothing proves page 1 ends with it.
      await expectLater(repo.page(1), throwsA(anything));
      store.values[QuranRepository.surahKey(2)] = jsonEncode([
        for (var a = 1; a <= FakeQuranApi.baqarahVerses; a++)
          Ayah.fromJson(FakeQuranApi.ayahJson(2, a)).toJson(),
      ]);
      final page = await repo.page(1);
      expect(page.data.map((a) => a.number).toList(), [1, 2, 3, 4, 5, 6, 7]);
      expect(page.fromCache, isTrue);
      expect(page.offline, isTrue);
      final page3 = await repo.page(3);
      expect(page3.data.map((a) => a.number).toList(), [
        for (var a = 10; a <= 19; a++) a,
      ]);
      // The last page of the fake (6) is not the end of the Qur'an: unproven.
      await expectLater(repo.page(6), throwsA(anything));
      expect(MushafRepository.totalPages, 604);
    },
  );

  testWidgets('the reader opens the mushaf at the current page; pages flip', (
    tester,
  ) async {
    await pumpReader(tester, surah: 2, initialAyah: 12);
    await tester.tap(find.byTooltip('Buka halaman mushaf'));
    await tester.pumpAndSettle();
    expect(find.byType(MushafPageScreen), findsOneWidget);
    expect(find.text('Halaman 3'), findsOneWidget);
    expect(find.text('Al-Baqarah · Juz 1'), findsOneWidget);
    // Ayah markers in Arabic-Indic digits, 10 to 19.
    expect(find.textContaining('﴿${arabicIndic(10)}﴾'), findsOneWidget);
    expect(find.textContaining('﴿${arabicIndic(19)}﴾'), findsOneWidget);

    // Next page sits to the left (mushaf order): drag to the right.
    await tester.drag(find.byType(PageView), const Offset(300, 0));
    await tester.pumpAndSettle();
    expect(find.text('Halaman 4'), findsOneWidget);
    expect(find.textContaining('﴿${arabicIndic(20)}﴾'), findsOneWidget);
    await tester.drag(find.byType(PageView), const Offset(-300, 0));
    await tester.pumpAndSettle();
    expect(find.text('Halaman 3'), findsOneWidget);
  });

  testWidgets('tapping an ayah on the page opens the reader there', (
    tester,
  ) async {
    await pumpReader(tester, surah: 1, initialAyah: 1);
    await tester.tap(find.byTooltip('Buka halaman mushaf'));
    await tester.pumpAndSettle();
    expect(find.text('Halaman 1'), findsOneWidget);
    // Al-Fatihah starts on the page: its name banner shows.
    expect(find.text('Al-Fatihah'), findsWidgets);
    // The text runs right to left: the first ayah starts at the top right.
    final paragraph = find.textContaining('﴿${arabicIndic(1)}﴾');
    await tester.tapAt(tester.getTopRight(paragraph) + const Offset(-24, 18));
    await tester.pumpAndSettle();
    expect(find.text('Al-Fatihah · 1'), findsOneWidget);
    await tester.tap(find.text('Buka di halaman baca'));
    await tester.pumpAndSettle();
    final readers = tester.widgetList<QuranReaderScreen>(
      find.byType(QuranReaderScreen),
    );
    expect(readers.last.surahNumber, 1);
  });
}
