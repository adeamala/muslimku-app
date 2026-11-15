import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muslimku/core/storage/content_cache.dart';
import 'package:muslimku/core/storage/local_store.dart';
import 'package:muslimku/features/quran/data/quran_themes_repository.dart';
import 'package:muslimku/features/quran/presentation/quran_list_shared.dart';
import 'package:muslimku/features/quran/presentation/theme_ayat_screen.dart';
import 'package:muslimku/shared/widgets/senja/senja.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/fake_quran_api.dart';
import 'pump_quran.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('QuranTheme parses MyQuran rows and matches a query loosely', () {
    final t = QuranTheme.fromJson(const {
      'id': '3',
      'name': 'Kemukjizatan Al-Qur’an, Satu Surah Pun Tidak Bisa Ditandingi',
    });
    expect(t.id, 3);
    expect(t.name, startsWith('Kemukjizatan'));
    expect(t.matches('kemukjizatan'), isTrue);
    expect(t.matches("al-qur'an"), isTrue, reason: 'curly vs straight quote');
    expect(t.matches('surah tandingi'), isTrue, reason: 'every word somewhere');
    expect(t.matches('zakat'), isFalse);
  });

  test('themes and their ayat are saved after the first load', () async {
    final api = FakeQuranApi();
    final store = MemoryLocalStore();
    final repo = QuranThemesRepository(api: api, cache: ContentCache(store));
    final themes = await repo.themes();
    expect(themes.data.map((t) => t.id), [1, 2, 500]);
    expect(themes.fromCache, isFalse);
    expect(await repo.themes().then((c) => c.fromCache), isTrue);
    expect(api.requests.where((r) => r == 'quran/tema/semua'), hasLength(1));

    final ayat = await repo.ayat(500);
    expect(ayat.data.map((a) => (a.surah, a.number)), [(2, 26), (2, 27)]);
    expect(ayat.data.first.arab, isNotEmpty);
    api.offline = true;
    final again = await repo.ayat(500);
    expect(again.fromCache, isTrue, reason: 'saved copy without a request');
    expect(store.values.keys, contains(QuranThemesRepository.ayatKey(500)));
  });

  testWidgets('Tema tab: search filters the index, a theme lists its ayat', (
    tester,
  ) async {
    final api = FakeQuranApi();
    await pumpQuran(tester, api: api);
    await tester.tap(find.text('Tema'));
    await settle(tester);
    expect(find.text('Perintah Beribadah kepada Allah'), findsOneWidget);
    expect(find.text('1.121 tema'), findsNothing);
    expect(find.text('3 tema'), findsOneWidget);

    await tester.enterText(find.byType(TextField).last, 'hijrah');
    await settle(tester);
    expect(find.text('Hijrah untuk Membela Agama Allah'), findsOneWidget);
    expect(find.text('Perintah Beribadah kepada Allah'), findsNothing);
    expect(find.text('1 tema'), findsOneWidget);

    await tester.tap(find.text('Hijrah untuk Membela Agama Allah'));
    await settle(tester);
    expect(find.byType(ThemeAyatScreen), findsOneWidget);
    expect(find.text('Hijrah untuk Membela Agama Allah'), findsOneWidget);
    expect(find.text('Al-Baqarah · 26'), findsOneWidget);
    expect(find.text('arti 2:26'), findsOneWidget);
    expect(find.text('2 ayat'), findsOneWidget);

    await tester.tap(find.text('Al-Baqarah · 26'));
    await settle(tester);
    expect(openedReader(tester), (2, 26));
  });

  testWidgets('Tema tab offline without a saved index shows the empty state', (
    tester,
  ) async {
    final api = FakeQuranApi(offline: true);
    final store = MemoryLocalStore();
    saveSurahList(store);
    await pumpQuran(tester, api: api, store: store);
    await tester.tap(find.text('Tema'));
    await settle(tester);
    expect(find.byType(SenjaEmptyState), findsOneWidget);
    expect(find.textContaining('Indeks tema'), findsWidgets);
    expect(QuranTabs.count, 4);
  });
}
