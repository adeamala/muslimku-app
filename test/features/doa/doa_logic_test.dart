import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muslimku/core/network/api_service.dart';
import 'package:muslimku/core/storage/content_cache.dart';
import 'package:muslimku/core/storage/local_store.dart';
import 'package:muslimku/features/doa/application/doa_provider.dart';

import '../../support/fake_husna_doa_api.dart';

List<Doa> _all() => [for (final d in FakeHusnaDoaApi.doa) Doa.fromJson(d)];

void main() {
  group('Doa.fromJson', () {
    test('reads the text from doa/artinya and cleans stray line breaks', () {
      final all = _all();
      final yunus = all[2];
      expect(
        yunus.title,
        'Doa Agar Terlepas dari Kesulitan / Istigfar Nabi Yunus',
      );
      expect(yunus.arabic, startsWith('لَا إِلَهَ إِلَّا أَنْتَ'));
      expect(yunus.category, 'quran');
      expect(yunus.key, yunus.title);

      final dosa = all[3];
      expect(
        dosa.meaning,
        'Ya Allah, ampunilah kesalahan, kebodohan dan keterlaluanku dalam '
        'segala urusan, kepada-Mu aku kembali.',
      );
    });

    test('attaches a waqf mark written after a space', () {
      expect(_all()[1].arabic, contains('رَحْمَةًۚ إِنَّكَ'));
    });

    test('falls back to arab/indo and to "lainnya" without a source', () {
      final doa = Doa.fromJson(const {
        'judul': ' Doa X ',
        'arab': 'عربي',
        'indo': 'Arti',
      });
      expect(doa.title, 'Doa X');
      expect(doa.arabic, 'عربي');
      expect(doa.meaning, 'Arti');
      expect(doa.category, 'lainnya');
      expect(doa.categoryLabel, 'Lainnya');
    });
  });

  test('category labels follow the design copy', () {
    expect(doaCategoryLabel('harian'), 'Harian');
    expect(doaCategoryLabel('quran'), "Al-Qur'an");
    expect(doaCategoryLabel('haji'), 'Haji');
    expect(doaCategoryLabel('hadits'), 'Hadits');
    expect(doaCategoryLabel('lainnya'), 'Lainnya');
    expect(doaCategoryLabel('ibadah'), 'Ibadah');
    expect(doaCategoryLabel('pilihan'), 'Pilihan');
    expect(doaCategoryLabel('dzikir pagi'), 'Dzikir pagi');
  });

  test('categories are counted and sorted by size, ties in data order', () {
    final categories = doaCategories(_all());
    expect(
      [for (final c in categories) (c.key, c.label, c.count)],
      [
        ('harian', 'Harian', 5),
        ('quran', "Al-Qur'an", 3),
        ('haji', 'Haji', 2),
        ('hadits', 'Hadits', 1),
      ],
    );
  });

  group('filterDoa', () {
    test('matches title and meaning without case, after trimming', () {
      final titles = [
        for (final d in filterDoa(_all(), query: '  MAKAN ')) d.title,
      ];
      expect(titles, ['Doa Sebelum Makan', 'Doa Sesudah Makan']);

      final byMeaning = filterDoa(_all(), query: 'bertawakkal');
      expect(byMeaning.single.title, 'Doa Keluar Rumah');
    });

    test('ignores the Arabic and the category name', () {
      expect(filterDoa(_all(), query: 'رَبَّنَا'), isEmpty);
      expect(filterDoa(_all(), query: 'harian'), isEmpty);
    });

    test('combines the category with the search', () {
      expect(filterDoa(_all(), category: 'haji'), hasLength(2));
      expect(
        [
          for (final d in filterDoa(_all(), category: 'harian', query: 'tidur'))
            d.title,
        ],
        ['Doa Sebelum Tidur'],
      );
      expect(filterDoa(_all(), category: 'haji', query: 'makan'), isEmpty);
      expect(filterDoa(_all()), hasLength(11));
    });
  });

  test(
    'favourites come first in the strip: newest first, unknown keys skipped',
    () {
      final favourites = favouriteDoas(_all(), [
        'Doa Sebelum Makan',
        'Doa yang sudah tidak ada',
        'Doa Keluar Rumah',
        'Doa Sebelum Tidur',
      ]);
      expect(
        [for (final d in favourites) d.title],
        ['Doa Sebelum Tidur', 'Doa Keluar Rumah', 'Doa Sebelum Makan'],
      );
    },
  );

  group('doaListProvider', () {
    test('saves doa/semua on the phone and falls back to it offline', () async {
      final api = FakeHusnaDoaApi();
      final store = MemoryLocalStore();
      ProviderContainer make() => ProviderContainer(
        overrides: [
          apiServiceProvider.overrideWithValue(api),
          localStoreProvider.overrideWithValue(store),
        ],
      );

      final first = make();
      addTearDown(first.dispose);
      final fresh = await first.read(doaListProvider.future);
      expect(fresh.data, hasLength(11));
      expect(fresh.offline, isFalse);
      expect(await store.read('lists/doa.json'), isNotNull);

      api.offline = true;
      final again = make();
      addTearDown(again.dispose);
      final saved = await again.read(doaListProvider.future);
      expect(saved.data.map((d) => d.title), contains('Doa Sebelum Makan'));
      expect(api.doaCalls, 1, reason: 'a fresh saved copy needs no request');

      // "Coba lagi" asks MyQuran again even though the saved copy is fresh.
      again.read(doaRefreshProvider.notifier).state++;
      final retried = await again.read(doaListProvider.future);
      expect(api.doaCalls, 2);
      expect(retried.offline, isTrue);
      expect(again.read(networkStatusProvider), isTrue);
    });
  });
}
