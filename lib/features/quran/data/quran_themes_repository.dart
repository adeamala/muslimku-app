import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muslimku/core/network/api_service.dart';
import 'package:muslimku/core/storage/content_cache.dart';
import 'package:muslimku/features/quran/domain/quran_models.dart';

/// One of MyQuran's 1 121 thematic entries (`quran/tema/semua`).
class QuranTheme {
  const QuranTheme({required this.id, required this.name});

  factory QuranTheme.fromJson(Map<String, dynamic> json) => QuranTheme(
    id: int.tryParse('${json['id']}'.trim()) ?? 0,
    name: '${json['name'] ?? ''}'.trim(),
  );

  final int id;
  final String name;

  /// Every word of [query] appears somewhere in the name; apostrophes and
  /// case do not matter ("al-qur'an" finds "Al-Qur’an").
  bool matches(String query) {
    final words = _fold(query).split(' ').where((w) => w.isNotEmpty);
    if (words.isEmpty) return true;
    final name = _fold(this.name);
    return words.every(name.contains);
  }

  static String _fold(String s) => s
      .toLowerCase()
      .replaceAll(RegExp('[’‘`´\']'), '')
      .replaceAll(RegExp(r'[^a-z0-9\s-]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

/// The thematic index of the Qur'an from MyQuran, saved like the other
/// lists (30 days), and the ayat of each theme, saved once opened.
class QuranThemesRepository {
  QuranThemesRepository({required this.api, required this.cache});

  final ApiService api;
  final ContentCache cache;

  static const themesKey = 'quran/themes.json';
  static String ayatKey(int theme) => 'quran/theme_$theme.json';

  Future<Cached<List<QuranTheme>>> themes({bool refresh = false}) async {
    final result = await cache.list(
      themesKey,
      () async => (await api.getJson('quran/tema/semua') as List)
          .cast<Map<dynamic, dynamic>>()
          .map(Map<String, dynamic>.from)
          .toList(),
      refresh: refresh,
    );
    return result.map(
      (rows) => [
        for (final row in rows)
          if (QuranTheme.fromJson(row) case final t when t.id > 0) t,
      ],
    );
  }

  /// Ayat of one theme (`quran/ayat/tema/<id>`); never refreshed on its own,
  /// the text does not change.
  Future<Cached<List<Ayah>>> ayat(int theme) async {
    final result = await cache.list(
      ayatKey(theme),
      () async => (await api.getJson('quran/ayat/tema/$theme') as List)
          .cast<Map<dynamic, dynamic>>()
          .map(Map<String, dynamic>.from)
          .toList(),
      maxAge: const Duration(days: 3650),
    );
    return result.map(
      (rows) =>
          [for (final row in rows) Ayah.fromJson(row)]
            ..sort((a, b) => a.id.compareTo(b.id)),
    );
  }
}

final quranThemesRepositoryProvider = Provider<QuranThemesRepository>(
  (ref) => QuranThemesRepository(
    api: ref.watch(apiServiceProvider),
    cache: ref.watch(contentCacheProvider),
  ),
);

final quranThemesProvider = FutureProvider<Cached<List<QuranTheme>>>(
  (ref) => ref.watch(quranThemesRepositoryProvider).themes(),
);

final themeAyatProvider = FutureProvider.autoDispose
    .family<Cached<List<Ayah>>, int>(
      (ref, theme) => ref.watch(quranThemesRepositoryProvider).ayat(theme),
    );
