import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muslimku/core/network/api_service.dart';
import 'package:muslimku/core/storage/local_store.dart';
import 'package:muslimku/features/doa/application/doa_provider.dart';

/// `doa/semua` as MyQuran sends it: the text is "doa", the meaning "artinya".
class _DoaApi extends ApiService {
  @override
  Future<List<Map<String, dynamic>>> getAllDoa() async => [
    {
      'id': '',
      'doa': 'اَلْحَمْدُ ِللهِ',
      'ayat': '',
      'latin': '',
      'artinya': 'Segala puji bagi Allah',
      'judul': 'Doa Sesudah Makan',
      'source': 'harian',
    },
  ];
}

void main() {
  test('the doa list keeps the Arabic text and its meaning', () async {
    final container = ProviderContainer(
      overrides: [
        apiServiceProvider.overrideWithValue(_DoaApi()),
        localStoreProvider.overrideWithValue(MemoryLocalStore()),
      ],
    );
    addTearDown(container.dispose);

    final item = (await container.read(doaListProvider.future)).data.single;
    expect(item.title, 'Doa Sesudah Makan');
    expect(item.arabic, 'اَلْحَمْدُ ِللهِ');
    expect(item.meaning, 'Segala puji bagi Allah');
  });
}
