import 'package:flutter_test/flutter_test.dart';
import 'package:muslimku/core/storage/content_cache.dart';
import 'package:muslimku/core/storage/local_store.dart';
import 'package:muslimku/features/quran/data/tafsir_repository.dart';
import 'package:muslimku/features/quran/presentation/reader/tafsir_sheet.dart';

import '../../../support/fake_quran_api.dart';
import 'reader_harness.dart';

void main() {
  test('a surah tafsir is fetched once from equran.id and saved', () async {
    final api = FakeQuranApi();
    final store = MemoryLocalStore();
    final repo = TafsirRepository(api: api, cache: ContentCache(store));
    final first = await repo.surah(2);
    expect(first.data[1], startsWith('Tafsir Kemenag 2:1.'));
    expect(first.data.length, FakeQuranApi.baqarahVerses);
    expect(first.fromCache, isFalse);
    expect(await repo.ayah(2, 40), 'Tafsir Kemenag 2:40. Penjelasan ayat.');
    api.offline = true;
    expect((await repo.surah(2)).fromCache, isTrue);
    expect(api.requests.where((r) => r.contains('equran.id')), hasLength(1));
    expect(store.values.keys, contains(TafsirRepository.key(2)));
    await expectLater(repo.surah(1), throwsA(anything));
  });

  testWidgets('Lainnya > Tafsir ayat opens the Kemenag tafsir of the ayah', (
    tester,
  ) async {
    final h = await pumpReader(tester, surah: 2, initialAyah: 3);
    await tester.tap(find.byTooltip('Lainnya untuk ayat 3'));
    await tester.pumpAndSettle();
    expect(find.text('Tafsir ayat'), findsOneWidget);
    await tester.tap(find.text('Tafsir ayat'));
    await tester.pumpAndSettle();
    expect(find.byType(TafsirSheet), findsOneWidget);
    expect(find.text('Tafsir Al-Baqarah'), findsOneWidget);
    expect(find.text('Ayat 3 dari 40'), findsOneWidget);
    expect(find.textContaining('Tafsir Kemenag 2:3.'), findsOneWidget);
    expect(find.textContaining('Kemenag'), findsWidgets);
    expect(find.textContaining('equran.id'), findsOneWidget);
    // Next ayah stays in the same sheet.
    await tester.tap(find.byTooltip('Ayat berikutnya'));
    await tester.pumpAndSettle();
    expect(find.text('Ayat 4 dari 40'), findsOneWidget);
    expect(find.textContaining('Tafsir Kemenag 2:4.'), findsOneWidget);
    expect(
      h.api.requests.where((r) => r.contains('equran.id')),
      hasLength(1),
      reason: 'the whole surah came in one request',
    );
  });

  testWidgets('offline without a saved tafsir shows a retry state', (
    tester,
  ) async {
    final api = FakeQuranApi();
    final h = await pumpReader(tester, surah: 2, api: api);
    api.offline = true;
    await tester.tap(find.byTooltip('Lainnya untuk ayat 1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tafsir ayat'));
    await tester.pumpAndSettle();
    expect(find.textContaining('belum tersimpan'), findsOneWidget);
    expect(find.text('Coba lagi'), findsOneWidget);
    api.offline = false;
    await tester.tap(find.text('Coba lagi'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Tafsir Kemenag 2:1.'), findsOneWidget);
    expect(h.store.values.keys, contains(TafsirRepository.key(2)));
  });
}
