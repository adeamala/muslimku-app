import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muslimku/core/network/api_service.dart';
import 'package:muslimku/core/storage/local_store.dart';
import 'package:muslimku/features/hadith/application/hadits_providers.dart';
import 'package:muslimku/shared/application/offline_data_provider.dart';

import '../../support/fake_hadits_api.dart';

/// The Hadits tab shares its saved lists with Pengaturan > Data offline
/// ([OfflineLists]): same keys and the same MyQuran calls.
class _Api extends FakeHaditsApi {
  /// Bukhari 6639 instead of the built-in 6638, so the saved copy can be told
  /// apart from the built-in totals.
  @override
  Future<List<Map<String, dynamic>>> getPerawiList() async {
    if (offline) throw Exception('offline');
    return [
      for (final p in FakeHaditsApi.perawiList)
        {...p, if (p['slug'] == 'bukhari') 'total': 6639},
    ];
  }

  @override
  Future<List<Map<String, dynamic>>> getAllDoa() async => [
    {'judul': 'Doa', 'doa': 'دعاء', 'artinya': 'Doa'},
  ];

  @override
  Future<List<Map<String, dynamic>>> getAllAsmaulHusna() async => [
    {'id': 1, 'latin': 'Ar-Rahman', 'arab': 'الرحمن', 'indo': 'Maha Pengasih'},
  ];
}

void main() {
  late _Api api;
  late ProviderContainer container;

  setUp(() {
    api = _Api();
    container = ProviderContainer(
      overrides: [
        apiServiceProvider.overrideWithValue(api),
        localStoreProvider.overrideWithValue(MemoryLocalStore()),
      ],
    );
    addTearDown(container.dispose);
  });

  test('the lists saved in Pengaturan open the Hadits tab offline', () async {
    await container.read(offlineListsProvider.notifier).saveAll();
    expect(container.read(offlineListsProvider).complete, isTrue);

    api.offline = true;
    final arbain = await container.read(arbainListProvider.future);
    // Served from the phone: without the saved copy this throws.
    expect(arbain.fromCache, isTrue);
    expect(arbain.data, hasLength(42));
    final perawi = await container.read(perawiBooksProvider.future);
    expect(perawi.data.firstWhere((b) => b.slug == 'bukhari').total, 6639);
  });

  test('Pengaturan counts the lists the Hadits tab saved', () async {
    await container.read(arbainListProvider.future);
    await container.read(perawiBooksProvider.future);
    await container.read(offlineListsProvider.notifier).refresh();
    expect(container.read(offlineListsProvider).saved, 2);
  });
}
