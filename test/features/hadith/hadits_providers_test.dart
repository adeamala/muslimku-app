import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muslimku/core/network/api_service.dart';
import 'package:muslimku/core/storage/content_cache.dart';
import 'package:muslimku/core/storage/local_store.dart';
import 'package:muslimku/core/time/clock_provider.dart';
import 'package:muslimku/features/hadith/application/hadits_bulughul_provider.dart';
import 'package:muslimku/features/hadith/application/hadits_last_read_provider.dart';
import 'package:muslimku/features/hadith/application/hadits_providers.dart';
import 'package:muslimku/features/hadith/domain/hadith_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_hadits_api.dart';

void main() {
  late FakeHaditsApi api;
  late MemoryLocalStore store;

  ProviderContainer container({Stream<DateTime>? clock}) {
    final c = ProviderContainer(
      overrides: [
        apiServiceProvider.overrideWithValue(api),
        localStoreProvider.overrideWithValue(store),
        clockProvider.overrideWith(
          (ref) => clock ?? Stream.value(DateTime(2026, 10, 25, 18, 2)),
        ),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  Future<void> settle() async {
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  /// Reads one hadith and keeps the auto-dispose provider alive meanwhile.
  Future<Cached<HaditsEntry>> entry(
    ProviderContainer c,
    HaditsBook book,
    int number,
  ) {
    final provider = haditsEntryProvider((book: book, number: number));
    c.listen(provider, (_, _) {});
    return c.read(provider.future);
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    api = FakeHaditsApi();
    store = MemoryLocalStore();
  });

  group('Arbain', () {
    test('loads the 42 hadiths once, sorted, and saves them', () async {
      final c = container();
      final list = await c.read(arbainListProvider.future);
      expect(list.data.map((e) => e.number), [for (var n = 1; n <= 42; n++) n]);
      final no16 = list.data[15];
      expect(no16.title, 'Janganlah Engkau Marah');
      expect(no16.citation, 'HR. Bukhari');
      expect(no16.favoriteKey, 'arbain:16');
      expect(store.values.keys, contains('lists/arbain.json'));

      final no17 = await entry(c, HaditsBook.arbain, 17);
      expect(no17.data.title, 'Berbuat Baik dalam Segala Hal');
      expect(
        api.count('hadits/arbain/semua'),
        1,
        reason: 'next comes from the list',
      );
    });

    test('a refresh without internet keeps the saved list', () async {
      await container().read(arbainListProvider.future);
      api.offline = true;
      final c = container();
      final cached = await c
          .read(haditsRepositoryProvider)
          .arbain(refresh: true);
      expect(cached.offline, isTrue);
      expect(cached.data, hasLength(42));
      expect(c.read(networkStatusProvider), isTrue);
    });
  });

  group('single hadiths', () {
    test('Bulughul Maram text is cleaned and saved per number', () async {
      final bm = await entry(container(), HaditsBook.bulughulMaram, 12);
      expect(bm.data.number, 12);
      expect(
        bm.data.translation,
        'Dari Abu Hurairah bahwa Rasulullah bersabda: '
        '"Isi Bulughul Maram nomor 12."',
      );
      expect(bm.data.arab, 'وَعَنْ أَبِي هُرَيْرَةَ 12');
      expect(bm.data.excerpt, '”Isi Bulughul Maram nomor 12.”');
      expect(store.values.keys, contains('hadits/bm/12.json'));
    });

    test('visited hadiths open again without internet', () async {
      final bukhari = HaditsBook.perawi.first;
      await entry(container(), bukhari, 52);
      await entry(container(), HaditsBook.bulughulMaram, 3);
      expect(store.values.keys, contains('hadits/bukhari/52.json'));

      api.offline = true;
      final c = container();
      final again = await entry(c, bukhari, 52);
      expect(again.data.number, 52);
      expect(again.data.citation, 'HR. Bukhari');
      expect(again.fromCache, isTrue);
      final bm = await entry(c, HaditsBook.bulughulMaram, 3);
      expect(bm.data.number, 3);

      await expectLater(
        entry(c, bukhari, 53),
        throwsA(anything),
        reason: 'never opened, so nothing is saved',
      );
    });
  });

  group('perawi list', () {
    test('keeps the display order and takes the totals from MyQuran', () async {
      api = _ChangedTotalsApi();
      final books = await container().read(perawiBooksProvider.future);
      expect(books.data.map((b) => b.slug), [
        'bukhari',
        'muslim',
        'abu-dawud',
        'tirmidzi',
        'nasai',
        'ibnu-majah',
        'ahmad',
        'malik',
        'darimi',
      ]);
      expect(books.data.first.total, 7000);
      expect(books.data.first.arabicName, 'البخاري');
      expect(store.values.keys, contains('lists/perawi.json'));
    });

    test('falls back to the built-in list without internet', () async {
      api.offline = true;
      final books = await container().read(perawiBooksProvider.future);
      expect(books.offline, isTrue);
      expect(books.data, HaditsBook.perawi);
    });
  });

  group('Bulughul Maram list', () {
    test('loads pages of 10 with at most 4 requests at a time', () async {
      final c = container();
      final notifier = c.read(bulughulListProvider.notifier);
      await notifier.loadMore();
      var state = c.read(bulughulListProvider);
      expect(state.items.map((e) => e.number), [
        for (var n = 1; n <= 10; n++) n,
      ]);
      expect(api.requests, hasLength(10));
      expect(api.maxInFlight, 4);

      await notifier.loadMore();
      state = c.read(bulughulListProvider);
      expect(state.items.last.number, 20);
      expect(state.nextNumber, 21);
      expect(state.hasMore, isTrue);
      expect(api.maxInFlight, 4);
    });

    test(
      'a failed number ends the page there; retry goes on from it',
      () async {
        api.failBulughul.add(14);
        final c = container();
        final notifier = c.read(bulughulListProvider.notifier);
        await notifier.loadMore();
        await notifier.loadMore();
        var state = c.read(bulughulListProvider);
        expect(state.items.last.number, 13);
        expect(state.error, isNotNull);
        expect(state.loading, isFalse);

        api.failBulughul.clear();
        await notifier.loadMore();
        state = c.read(bulughulListProvider);
        expect(state.error, isNull);
        expect(state.items.map((e) => e.number), [
          for (var n = 1; n <= 23; n++) n,
        ]);
      },
    );

    test('loads nothing twice while a page is on its way', () async {
      final c = container();
      final notifier = c.read(bulughulListProvider.notifier);
      await Future.wait([notifier.loadMore(), notifier.loadMore()]);
      expect(c.read(bulughulListProvider).items, hasLength(10));
      expect(api.requests, hasLength(10));
    });
  });

  group('Hadits hari ini', () {
    test('is the Arbain of the date and changes with the date only', () async {
      final clock = StreamController<DateTime>();
      addTearDown(clock.close);
      final c = container(clock: clock.stream);
      clock.add(DateTime(2026, 10, 25, 6));
      c.listen(clockProvider, (_, _) {});
      await c.read(clockProvider.future);
      await c.read(arbainListProvider.future);

      final numbers = <int?>[];
      c.listen<AsyncValue<HaditsEntry>>(
        dailyArbainProvider,
        (_, next) => numbers.add(next.valueOrNull?.number),
        fireImmediately: true,
      );
      // 25 Oct is day 298 of the year: (298 - 1) % 42 + 1 = No. 4.
      expect(numbers, [4]);
      expect(
        c.read(dailyArbainProvider).value?.title,
        'Takdir Setiap Manusia sudah Tertulis',
      );

      clock.add(DateTime(2026, 10, 25, 23, 59));
      await settle();
      expect(numbers, [4], reason: 'same date, so the same hadith');

      clock.add(DateTime(2026, 10, 26, 0, 1));
      await settle();
      expect(numbers, [4, 5]);
    });

    test('is an error while the Arbain list cannot load', () async {
      api.offline = true;
      final c = container();
      c.listen(dailyArbainProvider, (_, _) {});
      await expectLater(c.read(arbainListProvider.future), throwsA(anything));
      expect(c.read(dailyArbainProvider).hasError, isTrue);
    });

    test('converts to the model of the Beranda card', () async {
      final list = await container().read(arbainListProvider.future);
      final model = list.data[15].toArbainModel();
      expect(model.nomor, 16);
      expect(model.judul, 'Janganlah Engkau Marah');
      expect(model.arab, list.data[15].arab);
      expect(model.indo, list.data[15].translation);
    });
  });

  test('remembers the last number per perawi', () async {
    final c = container();
    final notifier = c.read(perawiLastNumberProvider.notifier);
    await notifier.ready;
    expect(notifier.numberFor('bukhari'), 1);
    notifier.remember('bukhari', 52);
    expect(c.read(perawiLastNumberProvider), {'bukhari': 52});
    await Future<void>.delayed(Duration.zero);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('hadits_last_bukhari'), 52);

    final freshContainer = container();
    final fresh = freshContainer.read(perawiLastNumberProvider.notifier);
    await fresh.ready;
    expect(fresh.numberFor('bukhari'), 52);
    expect(fresh.numberFor('muslim'), 1);
  });
}

class _ChangedTotalsApi extends FakeHaditsApi {
  @override
  Future<List<Map<String, dynamic>>> getPerawiList() async {
    final list = await super.getPerawiList();
    return [
      for (final p in list) p['slug'] == 'bukhari' ? {...p, 'total': 7000} : p,
    ];
  }
}
