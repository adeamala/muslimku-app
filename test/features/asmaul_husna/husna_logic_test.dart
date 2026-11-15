import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muslimku/core/network/api_service.dart';
import 'package:muslimku/core/storage/local_store.dart';
import 'package:muslimku/features/asmaul_husna/application/asmaul_husna_provider.dart';

import '../../support/fake_husna_doa_api.dart';

List<HusnaName> _names(int n) => [
  for (var i = 1; i <= n; i++)
    HusnaName(
      number: i,
      arabic: 'اسم $i',
      latin: 'Nama $i',
      meaning: 'Arti $i',
    ),
];

void main() {
  test('HusnaName reads husna/semua and tolerates a string id', () {
    final name = HusnaName.fromJson(const {
      'id': '4',
      'arab': 'الْقُدُّوْسُ',
      'latin': ' Al-Quddûsu ',
      'indo': 'Yang Mahasuci',
    });
    expect(name.number, 4);
    expect(name.arabic, 'الْقُدُّوْسُ');
    expect(name.latin, 'Al-Quddûsu');
    expect(name.meaning, 'Yang Mahasuci');
    expect(name.shareText, contains('Al-Quddûsu: Yang Mahasuci'));
    expect(name.shareText, contains('Asmaul Husna ke-4'));
  });

  group('nameOfTheDay', () {
    test('walks through the 99 names by day of the year', () {
      final names = _names(99);
      expect(nameOfTheDay(names, DateTime(2026, 1, 1)).number, 1);
      expect(nameOfTheDay(names, DateTime(2026, 1, 2, 23, 59)).number, 2);
      expect(nameOfTheDay(names, DateTime(2026, 4, 9)).number, 99);
      expect(nameOfTheDay(names, DateTime(2026, 4, 10)).number, 1);
      // Day 298: the design shows "1 dari 99" on 25 Oct 2026.
      expect(nameOfTheDay(names, DateTime(2026, 10, 25, 18, 2)).number, 1);
      expect(nameOfTheDay(names, DateTime(2026, 10, 26)).number, 2);
    });

    test('works with a shorter list', () {
      expect(nameOfTheDay(_names(13), DateTime(2026, 1, 14)).number, 1);
    });
  });

  test('the list is sorted by number and saved on the phone', () async {
    final store = MemoryLocalStore();
    final api = FakeHusnaDoaApi();
    final container = ProviderContainer(
      overrides: [
        apiServiceProvider.overrideWithValue(api),
        localStoreProvider.overrideWithValue(store),
      ],
    );
    addTearDown(container.dispose);

    final result = await container.read(husnaListProvider.future);
    expect(result.data.map((n) => n.number), [
      ...List.generate(12, (i) => i + 1),
      83,
    ]);
    expect(result.data.first.latin, 'Ar-Rahmânu');
    expect(await store.read('lists/husna.json'), isNotNull);

    api.offline = true;
    container.read(husnaRefreshProvider.notifier).state++;
    final retried = await container.read(husnaListProvider.future);
    expect(retried.offline, isTrue);
    expect(retried.data, hasLength(13));
  });
}
