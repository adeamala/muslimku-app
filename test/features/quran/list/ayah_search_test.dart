import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muslimku/core/storage/local_store.dart';
import 'package:muslimku/features/quran/data/quran_repository.dart';
import 'package:muslimku/features/quran/domain/ayah_search.dart';
import 'package:muslimku/features/quran/domain/quran_models.dart';
import 'package:muslimku/features/quran/presentation/ayah_search_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/fake_quran_api.dart';
import 'pump_quran.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('matching folds case, diacritics and punctuation', () {
    expect(
      foldForSearch('Yā ayyuhal-lażīna āmanū,'),
      'ya ayyuhal-lazina amanu',
    );
    expect(foldForSearch('  Maha  Pengasih '), 'maha pengasih');
    final ayah = Ayah.fromJson({
      ...FakeQuranApi.ayahJson(2, 2),
      'text':
          'Kitab (Al-Qur’an) ini tidak ada keraguan padanya; petunjuk bagi '
          'mereka yang bertakwa,',
      'latin': 'żālikal-kitābu lā raiba fīh(i), hudal lil-muttaqīn(a).',
    });
    expect(ayahMatches(ayah, 'keraguan'), isTrue);
    expect(ayahMatches(ayah, 'KITAB petunjuk'), isTrue, reason: 'all words');
    expect(ayahMatches(ayah, 'zalikal kitabu'), isTrue, reason: 'latin folded');
    expect(ayahMatches(ayah, 'muttaqin'), isTrue);
    expect(ayahMatches(ayah, 'sabar'), isFalse);
    expect(ayahMatches(ayah, 'ke'), isFalse, reason: 'shorter than 3 letters');
    final hits = highlightRanges(
      'Kitab ini tidak ada keraguan',
      'kitab keraguan',
    );
    expect(hits, [(0, 5), (20, 28)]);
  });

  test(
    'search runs over the saved surahs only, newest surah order kept',
    () async {
      final store = MemoryLocalStore();
      saveFatihah(store);
      store.values[QuranRepository.surahKey(2)] = jsonEncode([
        for (var a = 1; a <= 5; a++)
          Ayah.fromJson({
            ...FakeQuranApi.ayahJson(2, a),
            'text': a == 3
                ? 'orang yang beriman kepada yang gaib'
                : 'arti 2:$a',
          }).toJson(),
      ]);
      final results = await searchSavedAyat(store, 'arti');
      expect(
        results.map((r) => (r.ayah.surah, r.ayah.number)).take(3).toList(),
        [(1, 1), (1, 2), (1, 3)],
      );
      expect(results.length, 7 + 4, reason: '"arti 1:x" ×7 and "arti 2:x" ×4');
      expect(results.first.surahName, 'Al-Fatihah');
      final gaib = await searchSavedAyat(store, 'gaib beriman');
      expect(gaib.map((r) => (r.ayah.surah, r.ayah.number)), [(2, 3)]);
      expect(await searchSavedAyat(store, 'xyz'), isEmpty);
      expect(await searchSavedAyat(store, 'ar'), isEmpty, reason: 'too short');
      expect(
        (await searchSavedAyat(store, 'arti', limit: 5)).length,
        5,
        reason: 'capped',
      );
    },
  );

  testWidgets(
    'Surat tab: "Cari ayat" opens the search; results open the reader',
    (tester) async {
      final store = MemoryLocalStore();
      saveFatihah(store);
      await pumpQuran(tester, api: FakeQuranApi(), store: store);
      expect(find.text('Cari ayat di terjemahan'), findsOneWidget);
      await tester.tap(find.text('Cari ayat di terjemahan'));
      await settle(tester);
      expect(find.byType(AyahSearchScreen), findsOneWidget);
      expect(find.textContaining('1 dari 2 surat tersimpan'), findsOneWidget);

      await tester.enterText(find.byType(TextField).last, 'arti 1:5');
      await settle(tester);
      expect(find.text('1 ayat ditemukan'), findsOneWidget);
      expect(find.text('Al-Fatihah · 5'), findsOneWidget);
      await tester.tap(find.text('Al-Fatihah · 5'));
      await settle(tester);
      expect(openedReader(tester), (1, 5));
    },
  );

  testWidgets(
    'with nothing saved the search explains and offers the download',
    (tester) async {
      await pumpQuran(tester, api: FakeQuranApi());
      await tester.tap(find.text('Cari ayat di terjemahan'));
      await settle(tester);
      expect(find.textContaining('0 dari 2 surat tersimpan'), findsOneWidget);
      await tester.enterText(find.byType(TextField).last, 'arti');
      await settle(tester);
      expect(find.text('Tidak ada ayat yang cocok'), findsOneWidget);
      expect(find.textContaining('Simpan Al-Qur'), findsOneWidget);
    },
  );
}
