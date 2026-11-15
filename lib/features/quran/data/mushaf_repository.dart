import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muslimku/core/network/api_service.dart';
import 'package:muslimku/core/storage/content_cache.dart';
import 'package:muslimku/core/storage/local_store.dart';
import 'package:muslimku/features/quran/data/quran_repository.dart';
import 'package:muslimku/features/quran/domain/quran_models.dart';

/// The 604 mushaf pages: `quran/ayat/page/<n>` from MyQuran, saved on the
/// phone once opened; offline, a page is assembled from the saved surahs
/// (every ayah knows its page).
class MushafRepository {
  MushafRepository({
    required this.api,
    required this.store,
    required this.cache,
  });

  final ApiService api;
  final LocalStore store;
  final ContentCache cache;

  static const totalPages = 604;
  static String key(int page) =>
      'quran/page_${page.toString().padLeft(3, '0')}.json';

  Future<Cached<List<Ayah>>> page(int number) async {
    try {
      final result = await cache.list(
        key(number),
        () async => (await api.getJson('quran/ayat/page/$number') as List)
            .cast<Map<dynamic, dynamic>>()
            .map(Map<String, dynamic>.from)
            .toList(),
        maxAge: const Duration(days: 3650),
      );
      return result.map(_sorted);
    } catch (e) {
      final assembled = await _fromSavedSurahs(number);
      if (assembled.isEmpty) rethrow;
      await store.writeJson(key(number), {
        'savedAt': DateTime.now().toIso8601String(),
        'data': [for (final a in assembled) a.toJson()],
      });
      return Cached(assembled, fromCache: true, offline: true);
    }
  }

  static List<Ayah> _sorted(List<Map<String, dynamic>> rows) =>
      [for (final row in rows) Ayah.fromJson(row)]
        ..sort((a, b) => a.id.compareTo(b.id));

  /// Ayat of [page] among the surahs saved on the phone. Empty unless the
  /// page is provably whole: the ayah before its first one is saved on the
  /// previous page (or it is 1:1) and the ayah after its last one is saved on
  /// the next page (or it is the last ayah of the Qur'an). A page cut short
  /// because the next surah is not saved would mislead.
  Future<List<Ayah>> _fromSavedSurahs(int page) async {
    final keys = await store.keys(QuranRepository.surahPrefix);
    final pageOfId = <int, int>{};
    final out = <Ayah>[];
    for (final key in keys) {
      final json = await store.readJson(key);
      if (json is! List) continue;
      for (final row in json) {
        if (row is! Map) continue;
        final id = int.tryParse('${row['id']}') ?? 0;
        final p = int.tryParse('${row['page']}') ?? 0;
        pageOfId[id] = p;
        if (p == page) out.add(Ayah.fromJson(Map<String, dynamic>.from(row)));
      }
    }
    out.sort((a, b) => a.id.compareTo(b.id));
    if (out.isEmpty) return const [];
    for (var i = 1; i < out.length; i++) {
      if (out[i].id != out[i - 1].id + 1) return const [];
    }
    final first = out.first.id;
    final last = out.last.id;
    final wholeStart = first == 1 || pageOfId[first - 1] == page - 1;
    final wholeEnd = last == lastAyahId || pageOfId[last + 1] == page + 1;
    return wholeStart && wholeEnd ? out : const [];
  }

  /// Global id of 114:6.
  static const lastAyahId = 6236;
}

final mushafRepositoryProvider = Provider<MushafRepository>(
  (ref) => MushafRepository(
    api: ref.watch(apiServiceProvider),
    store: ref.watch(localStoreProvider),
    cache: ref.watch(contentCacheProvider),
  ),
);

final mushafPageProvider = FutureProvider.autoDispose
    .family<Cached<List<Ayah>>, int>(
      (ref, page) => ref.watch(mushafRepositoryProvider).page(page),
    );
