import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:muslimku/core/network/api_service.dart';
import 'package:muslimku/core/storage/content_cache.dart';

/// Tajweed markup per ayah from alquran.cloud (`v1/surah/<n>/quran-tajweed`,
/// Uthmani text), one request per surah, saved on the phone for good.
class TajweedRepository {
  TajweedRepository({required this.api, required this.cache});

  final ApiService api;
  final ContentCache cache;

  static const source = 'https://api.alquran.cloud/v1/surah/';
  static String key(int surah) =>
      'quran/tajweed_${surah.toString().padLeft(3, '0')}.json';

  /// ayah number → markup, for the whole surah.
  Future<Cached<Map<int, String>>> surah(int number) async {
    final result = await cache.object(key(number), () async {
      final body = await api.getExternalJson('$source$number/quran-tajweed');
      final data = body is Map ? body['data'] : null;
      final rows = data is Map ? data['ayahs'] : null;
      if (rows is! List || rows.isEmpty) return null;
      return {
        for (final row in rows)
          if (row is Map) '${row['numberInSurah']}': '${row['text'] ?? ''}',
      };
    }, maxAge: const Duration(days: 3650));
    return result.map(
      (map) => {
        for (final e in map.entries)
          if (int.tryParse(e.key) case final n?) n: '${e.value}',
      },
    );
  }
}

final tajweedRepositoryProvider = Provider<TajweedRepository>(
  (ref) => TajweedRepository(
    api: ref.watch(apiServiceProvider),
    cache: ref.watch(contentCacheProvider),
  ),
);

/// The markup of a surah, or null while loading / when unavailable (the
/// reader then shows the plain Kemenag text).
final surahTajweedProvider = FutureProvider.autoDispose
    .family<Map<int, String>?, int>((ref, surah) async {
      try {
        return (await ref.watch(tajweedRepositoryProvider).surah(surah)).data;
      } catch (_) {
        return null;
      }
    });
