import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muslimku/core/state/mounted_flag.dart';
import 'package:muslimku/features/quran/data/murottal_store.dart';
import 'package:muslimku/features/quran/domain/quran_models.dart';
import 'package:muslimku/features/quran/domain/reciters.dart';
import 'package:muslimku/features/reading/application/reading_settings_provider.dart';

/// Downloads one audio file. Abstract so tests serve bytes without network.
abstract class AudioFetcher {
  Future<List<int>> fetch(String url);
}

class DioAudioFetcher implements AudioFetcher {
  DioAudioFetcher()
    : _dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 60),
          responseType: ResponseType.bytes,
        ),
      );

  final Dio _dio;

  @override
  Future<List<int>> fetch(String url) async {
    final response = await _dio.get<List<int>>(url);
    final bytes = response.data;
    if (bytes == null || bytes.isEmpty) throw Exception('empty $url');
    return bytes;
  }
}

final audioFetcherProvider = Provider<AudioFetcher>((ref) => DioAudioFetcher());

/// What the phone holds of one surah for one reciter, plus a running
/// download if any.
class SurahMurottalStatus {
  const SurahMurottalStatus({
    required this.surah,
    required this.reciter,
    required this.total,
    required this.saved,
    required this.bytes,
    this.running = false,
    this.failedAt,
  });

  final int surah;
  final Reciter reciter;
  final int total;
  final int saved;
  final int bytes;
  final bool running;

  /// Ayah number where the last download stopped, null when it ended well.
  final int? failedAt;

  bool get complete => total > 0 && saved >= total;
  double get progress => total == 0 ? 0 : saved / total;

  SurahMurottalStatus copyWith({
    int? saved,
    int? bytes,
    bool? running,
    int? failedAt,
    bool clearFailure = false,
  }) => SurahMurottalStatus(
    surah: surah,
    reciter: reciter,
    total: total,
    saved: saved ?? this.saved,
    bytes: bytes ?? this.bytes,
    running: running ?? this.running,
    failedAt: clearFailure ? null : failedAt ?? this.failedAt,
  );
}

/// Rough size before anything is saved: the CDN's files average
/// ~5.5 kB/s at 128 kbps, ayat average ~12 s.
int estimateMurottalBytes(Reciter reciter, int ayat) =>
    (ayat * 12 * reciter.kbps * 1000 / 8).round();

/// Per-surah download of the murottal, ayah by ayah, for the reciter chosen
/// in Pengaturan. Keyed by `<reciter>/<surah>`; a failed ayah stops the run
/// and what came stays, so "Lanjutkan unduhan" resumes from there.
class MurottalDownloadController
    extends Notifier<Map<String, SurahMurottalStatus>> {
  late MurottalStore _store;
  late AudioFetcher _fetcher;
  late MountedFlag _alive;
  final _cancelled = <String>{};

  @override
  Map<String, SurahMurottalStatus> build() {
    _store = ref.watch(murottalStoreProvider);
    _fetcher = ref.watch(audioFetcherProvider);
    _alive = MountedFlag(ref);
    _cancelled.clear();
    return const {};
  }

  static String keyOf(Reciter reciter, int surah) => '${reciter.name}/$surah';

  SurahMurottalStatus? statusOf(Reciter reciter, int surah) =>
      state[keyOf(reciter, surah)];

  /// Reads the phone for [ayat] of [surah] (no network).
  Future<SurahMurottalStatus> refresh(
    int surah,
    List<Ayah> ayat,
    Reciter reciter,
  ) async {
    var saved = 0;
    for (final a in ayat) {
      if (await _store.has(reciter, a.id)) saved++;
    }
    final bytes = await _store.bytesOf(reciter, ayat.map((a) => a.id));
    final key = keyOf(reciter, surah);
    final previous = state[key];
    final status = SurahMurottalStatus(
      surah: surah,
      reciter: reciter,
      total: ayat.length,
      saved: saved,
      bytes: bytes,
      running: previous?.running ?? false,
      failedAt: previous?.failedAt,
    );
    if (_alive.mounted) state = {...state, key: status};
    return status;
  }

  /// Downloads the ayat of [surah] that are not saved yet, in order.
  Future<void> download(int surah, List<Ayah> ayat, Reciter reciter) async {
    final key = keyOf(reciter, surah);
    if (state[key]?.running ?? false) return;
    _cancelled.remove(key);
    var status = await refresh(surah, ayat, reciter);
    status = status.copyWith(running: true, clearFailure: true);
    state = {...state, key: status};
    final sorted = [...ayat]..sort((a, b) => a.number.compareTo(b.number));
    for (final a in sorted) {
      if (_cancelled.contains(key) || !_alive.mounted) break;
      if (await _store.has(reciter, a.id)) continue;
      try {
        final bytes = await _fetcher.fetch(a.audioUrlFor(reciter));
        await _store.write(reciter, a.id, bytes);
        status = status.copyWith(
          saved: status.saved + 1,
          bytes: status.bytes + bytes.length,
        );
        if (_alive.mounted) state = {...state, key: status};
      } catch (_) {
        status = status.copyWith(running: false, failedAt: a.number);
        if (_alive.mounted) state = {...state, key: status};
        return;
      }
    }
    status = status.copyWith(running: false, clearFailure: true);
    if (_alive.mounted) state = {...state, key: status};
  }

  void cancel(Reciter reciter, int surah) =>
      _cancelled.add(keyOf(reciter, surah));

  Future<void> delete(int surah, List<Ayah> ayat, Reciter reciter) async {
    final key = keyOf(reciter, surah);
    _cancelled.add(key);
    await _store.delete(reciter, ayat.map((a) => a.id));
    if (!_alive.mounted) return;
    state = {
      ...state,
      key: SurahMurottalStatus(
        surah: surah,
        reciter: reciter,
        total: ayat.length,
        saved: 0,
        bytes: 0,
      ),
    };
  }

  Future<void> deleteAll() async {
    _cancelled.addAll(state.keys);
    await _store.deleteAll();
    // A fresh map, so listeners (the totals) re-read even when nothing ran.
    if (_alive.mounted) state = <String, SurahMurottalStatus>{};
  }
}

final murottalDownloadProvider =
    NotifierProvider<
      MurottalDownloadController,
      Map<String, SurahMurottalStatus>
    >(MurottalDownloadController.new);

/// Status of the current surah for the chosen reciter, refreshed from the
/// phone when the surah or the reciter changes.
final surahMurottalProvider = FutureProvider.autoDispose
    .family<SurahMurottalStatus, (int, List<Ayah>)>((ref, arg) {
      final reciter = ref.watch(
        readingSettingsProvider.select((s) => s.reciter),
      );
      final (surah, ayat) = arg;
      return ref
          .read(murottalDownloadProvider.notifier)
          .refresh(surah, ayat, reciter);
    });

/// Saved murottal on the phone, all reciters: (ayat, bytes).
final murottalTotalsProvider = FutureProvider.autoDispose<(int, int)>((
  ref,
) async {
  ref.watch(murottalDownloadProvider); // re-read after any change
  final store = ref.watch(murottalStoreProvider);
  return (await store.count(), await store.bytes());
});
