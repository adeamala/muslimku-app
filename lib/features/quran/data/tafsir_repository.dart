import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:muslimku/core/network/api_service.dart';
import 'package:muslimku/core/storage/content_cache.dart';

/// Tafsir Kemenag per ayah, from equran.id (`api/v2/tafsir/<surah>`), one
/// request per surah, saved on the phone for good (the text does not change).
class TafsirRepository {
  TafsirRepository({required this.api, required this.cache});

  final ApiService api;
  final ContentCache cache;

  static const source = 'https://equran.id/api/v2/tafsir/';
  static String key(int surah) =>
      'quran/tafsir_${surah.toString().padLeft(3, '0')}.json';

  /// ayah number → tafsir text, for the whole surah.
  Future<Cached<Map<int, String>>> surah(int number) async {
    final result = await cache.object(key(number), () async {
      final body = await api.getExternalJson('$source$number');
      final data = body is Map ? body['data'] : null;
      final rows = data is Map ? data['tafsir'] : null;
      if (rows is! List || rows.isEmpty) return null;
      return {
        for (final row in rows)
          if (row is Map) '${row['ayat']}': '${row['teks'] ?? ''}'.trim(),
      };
    }, maxAge: const Duration(days: 3650));
    return result.map(
      (map) => {
        for (final e in map.entries)
          if (int.tryParse(e.key) case final n?) n: '${e.value}',
      },
    );
  }

  Future<String?> ayah(int surah, int number) async =>
      (await this.surah(surah)).data[number];
}

final tafsirRepositoryProvider = Provider<TafsirRepository>(
  (ref) => TafsirRepository(
    api: ref.watch(apiServiceProvider),
    cache: ref.watch(contentCacheProvider),
  ),
);

final surahTafsirProvider = FutureProvider.autoDispose
    .family<Cached<Map<int, String>>, int>(
      (ref, surah) => ref.watch(tafsirRepositoryProvider).surah(surah),
    );
