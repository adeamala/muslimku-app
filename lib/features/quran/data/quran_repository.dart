import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muslimku/core/network/api_service.dart';
import 'package:muslimku/core/state/mounted_flag.dart';
import 'package:muslimku/core/storage/content_cache.dart';
import 'package:muslimku/core/storage/local_store.dart';
import 'package:muslimku/features/quran/domain/quran_models.dart';

/// Progress of [QuranRepository.downloadAll].
class QuranDownloadProgress {
  const QuranDownloadProgress({
    required this.doneJuz,
    required this.storedSurahs,
  });

  /// Juz fetched so far (out of 30).
  final int doneJuz;

  /// Surahs fully saved on the phone (out of 114).
  final int storedSurahs;
}

/// Qur'an text from MyQuran, saved on the phone so it can be read offline.
///
/// A surah is saved after it was opened once, or for all 114 surahs with
/// [downloadAll] (30 `quran/ayat/juz/<n>` requests, about 6 MB).
class QuranRepository {
  QuranRepository({
    required this.api,
    required this.store,
    required this.cache,
  });

  final ApiService api;
  final LocalStore store;
  final ContentCache cache;

  static const totalSurahs = 114;
  static const totalJuz = 30;
  static const surahListKey = 'quran/surah_list.json';
  static const juzListKey = 'quran/juz_list.json';
  static const surahPrefix = 'quran/surah_';
  static const _batchSize = 30;
  static const _parallel = 4;

  static String surahKey(int number) =>
      '$surahPrefix${number.toString().padLeft(3, '0')}.json';

  Future<Cached<List<Surah>>> surahs({bool refresh = false}) async {
    final result = await cache.list(
      surahListKey,
      api.getAllSurat,
      refresh: refresh,
    );
    return result.map((rows) => [for (final row in rows) Surah.fromJson(row)]);
  }

  Future<Cached<List<JuzInfo>>> juzList({bool refresh = false}) async {
    final result = await cache.list(
      juzListKey,
      api.getAllJuz,
      refresh: refresh,
    );
    return result.map(
      (rows) =>
          [for (final row in rows) JuzInfo.fromJson(row)]
            ..sort((a, b) => a.number.compareTo(b.number)),
    );
  }

  /// The saved surah, or null when it was never downloaded.
  Future<List<Ayah>?> savedAyat(int surah) async {
    final json = await store.readJson(surahKey(surah));
    if (json is! List || json.isEmpty) return null;
    return [
      for (final row in json)
        Ayah.fromJson(Map<String, dynamic>.from(row as Map)),
    ];
  }

  /// All ayat of [surah]: from the phone when saved, otherwise downloaded in
  /// batches of 30 (4 at a time) and saved. Throws when offline and not saved.
  Future<Cached<List<Ayah>>> ayat(Surah surah) async {
    final saved = await savedAyat(surah.number);
    if (saved != null && saved.length >= surah.verseCount) {
      return Cached(saved, fromCache: true);
    }
    final ranges = <(int, int)>[
      for (var start = 1; start <= surah.verseCount; start += _batchSize)
        (start, math.min(surah.verseCount, start + _batchSize - 1)),
    ];
    final batches = await _pool(ranges, _parallel, (range) async {
      final data = await api.getJson(
        'quran/ayat/${surah.number}/${range.$1}-${range.$2}',
      );
      return [
        for (final row in data as List)
          Ayah.fromJson(Map<String, dynamic>.from(row as Map)),
      ];
    });
    final ayat = [for (final b in batches) ...b]
      ..sort((a, b) => a.number.compareTo(b.number));
    if (ayat.length >= surah.verseCount) {
      await store.writeJson(surahKey(surah.number), [
        for (final a in ayat) a.toJson(),
      ]);
    }
    return Cached(ayat);
  }

  /// Numbers of the surahs saved on the phone.
  Future<Set<int>> storedSurahs() async {
    final keys = await store.keys(surahPrefix);
    return {
      for (final key in keys)
        if (int.tryParse(key.substring(surahPrefix.length).split('.').first)
            case final n?)
          n,
    };
  }

  Future<int> storedBytes() => store.size(surahPrefix);

  Future<void> deleteDownloads() async {
    for (final key in await store.keys(surahPrefix)) {
      await store.delete(key);
    }
  }

  /// Saves every surah that is not on the phone yet, juz by juz.
  /// Surahs spanning several juz are written once all their ayat arrived.
  Stream<QuranDownloadProgress> downloadAll(
    List<Surah> surahs, {
    List<JuzInfo> juz = const [],
  }) async* {
    final verses = {for (final s in surahs) s.number: s.verseCount};
    final stored = await storedSurahs();
    final pending = <int, Map<int, Ayah>>{};
    var done = 0;
    yield QuranDownloadProgress(doneJuz: 0, storedSurahs: stored.length);
    for (var j = 1; j <= totalJuz; j++) {
      if (verses.isNotEmpty && verses.keys.every(stored.contains)) {
        yield QuranDownloadProgress(
          doneJuz: totalJuz,
          storedSurahs: stored.length,
        );
        return;
      }
      final info = juz.where((x) => x.number == j).firstOrNull;
      final needed =
          info == null ||
          [
            for (var s = info.startSurah; s <= info.endSurah; s++) s,
          ].any((s) => !stored.contains(s));
      if (needed) {
        final data = await api.getJson('quran/ayat/juz/$j');
        for (final row in data as List) {
          final ayah = Ayah.fromJson(Map<String, dynamic>.from(row as Map));
          if (stored.contains(ayah.surah)) continue;
          (pending[ayah.surah] ??= {})[ayah.number] = ayah;
        }
        for (final entry in pending.entries.toList()) {
          final total = verses[entry.key];
          if (total != null && entry.value.length >= total) {
            final list = entry.value.values.toList()
              ..sort((a, b) => a.number.compareTo(b.number));
            await store.writeJson(surahKey(entry.key), [
              for (final a in list) a.toJson(),
            ]);
            stored.add(entry.key);
            pending.remove(entry.key);
          }
        }
      }
      done++;
      yield QuranDownloadProgress(doneJuz: done, storedSurahs: stored.length);
    }
  }
}

Future<List<R>> _pool<T, R>(
  List<T> items,
  int parallel,
  Future<R> Function(T) task,
) async {
  final results = List<R?>.filled(items.length, null);
  var next = 0;
  Future<void> worker() async {
    while (next < items.length) {
      final i = next++;
      results[i] = await task(items[i]);
    }
  }

  await Future.wait([
    for (var i = 0; i < math.min(parallel, items.length); i++) worker(),
  ]);
  return results.cast<R>();
}

final quranRepositoryProvider = Provider<QuranRepository>(
  (ref) => QuranRepository(
    api: ref.watch(apiServiceProvider),
    store: ref.watch(localStoreProvider),
    cache: ref.watch(contentCacheProvider),
  ),
);

/// The 114 surahs (saved for 30 days, refreshed after that).
final surahListProvider = FutureProvider<Cached<List<Surah>>>(
  (ref) => ref.watch(quranRepositoryProvider).surahs(),
);

final juzListProvider = FutureProvider<Cached<List<JuzInfo>>>(
  (ref) => ref.watch(quranRepositoryProvider).juzList(),
);

/// One surah's ayat. Saved after the first successful download.
final surahAyatProvider = FutureProvider.autoDispose
    .family<Cached<List<Ayah>>, int>((ref, number) async {
      final surahs = await ref.watch(surahListProvider.future);
      final surah = surahs.data.firstWhere((s) => s.number == number);
      final result = await ref.watch(quranRepositoryProvider).ayat(surah);
      ref.invalidate(storedSurahsProvider);
      return result;
    });

final storedSurahsProvider = FutureProvider<Set<int>>(
  (ref) => ref.watch(quranRepositoryProvider).storedSurahs(),
);

class QuranDownloadState {
  const QuranDownloadState({
    this.running = false,
    this.doneJuz = 0,
    this.storedSurahs = 0,
    this.storedBytes = 0,
    this.error,
  });

  final bool running;
  final int doneJuz;
  final int storedSurahs;
  final int storedBytes;
  final String? error;

  bool get complete => storedSurahs >= QuranRepository.totalSurahs;
  double get progress => storedSurahs / QuranRepository.totalSurahs;
}

/// "Simpan Al-Qur'an di HP": downloads every surah that is not saved yet.
/// Used by the Al-Qur'an tab and by Pengaturan > Data offline.
final quranDownloadProvider =
    NotifierProvider<QuranDownloadNotifier, QuranDownloadState>(
      QuranDownloadNotifier.new,
    );

class QuranDownloadNotifier extends Notifier<QuranDownloadState> {
  @override
  QuranDownloadState build() {
    _alive = MountedFlag(ref);
    ref.onDispose(() => _sub?.cancel());
    refresh();
    return const QuranDownloadState();
  }

  late MountedFlag _alive;

  StreamSubscription<QuranDownloadProgress>? _sub;
  Completer<void>? _done;

  QuranRepository get _repo => ref.read(quranRepositoryProvider);

  Future<void> refresh() async {
    final stored = await _repo.storedSurahs();
    final bytes = await _repo.storedBytes();
    if (!_alive.mounted) return;
    state = QuranDownloadState(
      running: state.running,
      doneJuz: state.doneJuz,
      storedSurahs: stored.length,
      storedBytes: bytes,
    );
  }

  Future<void> start() async {
    if (state.running) return;
    state = QuranDownloadState(
      running: true,
      storedSurahs: state.storedSurahs,
      storedBytes: state.storedBytes,
    );
    final done = _done = Completer<void>();
    try {
      final surahs = await ref.read(surahListProvider.future);
      final juz = await ref
          .read(juzListProvider.future)
          .then((j) => j.data, onError: (_) => const <JuzInfo>[]);
      if (done.isCompleted) return _finish(); // cancelled meanwhile
      _sub = _repo
          .downloadAll(surahs.data, juz: juz)
          .listen(
            (p) {
              if (!_alive.mounted) return;
              state = QuranDownloadState(
                running: true,
                doneJuz: p.doneJuz,
                storedSurahs: p.storedSurahs,
                storedBytes: state.storedBytes,
              );
            },
            onError: (Object e) {
              if (!done.isCompleted) done.completeError(e);
            },
            onDone: () {
              if (!done.isCompleted) done.complete();
            },
            cancelOnError: true,
          );
      await done.future;
      if (_alive.mounted) ref.read(networkStatusProvider.notifier).markOnline();
      _finish();
    } catch (_) {
      if (_alive.mounted) {
        ref.read(networkStatusProvider.notifier).markOffline();
      }
      _finish(error: 'Unduhan terhenti. Coba lagi saat ada internet.');
    }
  }

  void cancel() {
    _sub?.cancel();
    _sub = null;
    final done = _done;
    if (done != null && !done.isCompleted) done.complete();
  }

  Future<void> deleteAll() async {
    cancel();
    await _repo.deleteDownloads();
    ref.invalidate(storedSurahsProvider);
    await refresh();
  }

  void _finish({String? error}) {
    _sub = null;
    if (!_alive.mounted) return;
    state = QuranDownloadState(
      storedSurahs: state.storedSurahs,
      storedBytes: state.storedBytes,
      error: error,
    );
    ref.invalidate(storedSurahsProvider);
    refresh();
  }
}
