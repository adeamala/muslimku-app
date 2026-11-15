import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:muslimku/core/storage/content_cache.dart';
import 'package:muslimku/core/storage/local_store.dart';
import 'package:muslimku/core/utils/arabic_text.dart';
import 'package:muslimku/features/quran/data/quran_repository.dart';
import 'package:muslimku/features/quran/domain/quran_models.dart';

import '../support/fake_quran_api.dart';

void main() {
  group('normalizeQuranText', () {
    test('attaches a waqf mark written after a space', () {
      expect(normalizeQuranText('يٰسۤ ۚ'), 'يٰسۤۚ');
      expect(normalizeQuranText('الْحَكِيْمِۙ'), 'الْحَكِيْمِۙ');
    });

    test('keeps rub el hizb and ayah numbers apart', () {
      expect(normalizeQuranText('۞ سَيَقُولُ'), '۞ سَيَقُولُ');
      expect(normalizeQuranText('قَدِيْرٌ ۝'), 'قَدِيْرٌ ۝');
    });
  });

  group('LocalStore', () {
    late Directory tmp;
    setUp(() => tmp = Directory.systemTemp.createTempSync('muslimku_store'));
    tearDown(() => tmp.deleteSync(recursive: true));

    for (final kind in ['file', 'memory']) {
      test('$kind store reads, lists, sizes and deletes', () async {
        final LocalStore store = kind == 'file'
            ? FileLocalStore(baseDir: () async => tmp)
            : MemoryLocalStore();
        expect(await store.read('quran/surah_001.json'), isNull);
        await store.writeJson('quran/surah_001.json', [1, 2]);
        await store.write('quran/surah_002.json', 'abc');
        await store.write('lists/doa.json', '{}');
        expect(await store.readJson('quran/surah_001.json'), [1, 2]);
        expect(await store.keys('quran/'), [
          'quran/surah_001.json',
          'quran/surah_002.json',
        ]);
        expect(await store.size('quran/'), 8);
        await store.delete('quran/surah_002.json');
        expect(await store.keys('quran/'), ['quran/surah_001.json']);
      });
    }

    test('a file store without a directory behaves as empty', () async {
      final store = FileLocalStore(
        baseDir: () async => throw Exception('no plugin'),
      );
      await store.write('a', 'b');
      expect(await store.read('a'), isNull);
      expect(await store.keys(''), isEmpty);
    });
  });

  group('ContentCache', () {
    late MemoryLocalStore store;
    late DateTime now;
    late List<String> events;
    late ContentCache cache;

    setUp(() {
      store = MemoryLocalStore();
      now = DateTime(2026, 10, 25, 10);
      events = [];
      cache = ContentCache(
        store,
        clock: () => now,
        onOffline: () => events.add('offline'),
        onOnline: () => events.add('online'),
      );
    });

    test(
      'saves fresh data and serves it without a request while fresh',
      () async {
        var calls = 0;
        Future<List<Map<String, dynamic>>?> fetch() async {
          calls++;
          return [
            {'judul': 'Doa $calls'},
          ];
        }

        final first = await cache.list('lists/doa.json', fetch);
        expect(first.fromCache, isFalse);
        now = now.add(const Duration(days: 3));
        final second = await cache.list('lists/doa.json', fetch);
        expect(second.fromCache, isTrue);
        expect(second.data.single['judul'], 'Doa 1');
        expect(calls, 1);
        expect(events, ['online']);
      },
    );

    test('falls back to the saved copy when the refresh fails', () async {
      await cache.list(
        'k',
        () async => [
          {'a': 1},
        ],
      );
      now = now.add(const Duration(days: 40));
      final result = await cache.list(
        'k',
        () async => throw Exception('offline'),
      );
      expect(result.offline, isTrue);
      expect(result.data.single['a'], 1);
      expect(result.savedAt, DateTime(2026, 10, 25, 10));
      expect(events.last, 'offline');
    });

    test('rethrows when there is nothing saved', () async {
      expect(
        () => cache.list('k', () async => throw Exception('offline')),
        throwsException,
      );
    });
  });

  group('QuranRepository', () {
    late FakeQuranApi api;
    late MemoryLocalStore store;
    late QuranRepository repo;

    setUp(() {
      api = FakeQuranApi();
      store = MemoryLocalStore();
      repo = QuranRepository(
        api: api,
        store: store,
        cache: ContentCache(store),
      );
    });

    test('downloads a surah in batches of 30, sorted, and keeps it', () async {
      final baqarah = FakeQuranApi.surahs[1];
      final result = await repo.ayat(baqarah);
      expect(result.fromCache, isFalse);
      expect(result.data.map((a) => a.number), List.generate(40, (i) => i + 1));
      expect(result.data.first.arab, 'الۤمّۤۚ');
      expect(result.data.first.latin, 'latin 2:1');
      expect(api.requests, ['quran/ayat/2/1-30', 'quran/ayat/2/31-40']);

      api.offline = true;
      final again = await repo.ayat(baqarah);
      expect(again.fromCache, isTrue);
      expect(again.data, hasLength(40));
      expect(await repo.storedSurahs(), {2});
    });

    test('an unsaved surah fails offline', () async {
      api.offline = true;
      expect(() => repo.ayat(FakeQuranApi.surahs.first), throwsException);
    });

    test(
      'downloadAll saves surahs that span several juz once complete',
      () async {
        final juz = (await repo.juzList()).data;
        expect(juz.first.range, 'Al-Fatihah 1 – Al-Baqarah 25');
        expect(juz.last.opening, 'سَيَقُولُ السُّفَهَاءُ');
        final progress = await repo
            .downloadAll(FakeQuranApi.surahs, juz: juz)
            .toList();
        expect(progress.map((p) => (p.doneJuz, p.storedSurahs)), [
          (0, 0),
          (1, 1),
          (2, 2),
          (30, 2),
        ]);
        expect(await repo.storedSurahs(), {1, 2});
        final saved = await repo.savedAyat(2);
        expect(saved!.length, FakeQuranApi.baqarahVerses);
        expect(saved.last.juz, 2);

        api.requests.clear();
        await repo.downloadAll(FakeQuranApi.surahs, juz: juz).drain<void>();
        expect(api.requests, isEmpty, reason: 'everything is saved already');
      },
    );

    test('juz boundaries', () {
      final juz2 = JuzInfo.fromJson(const {
        'number': '2',
        'surah_id_start': '2',
        'verse_start': '142',
        'surah_id_end': '2',
        'verse_end': '252',
        'name_start_id': 'Al-Baqarah',
        'name_end_id': 'Al-Baqarah',
        'ayat_arab': '',
      });
      expect(juz2.contains(2, 141), isFalse);
      expect(juz2.contains(2, 142), isTrue);
      expect(juz2.endsAt(2, 252), isTrue);
    });
  });
}
