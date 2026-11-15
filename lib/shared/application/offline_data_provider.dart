import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muslimku/core/network/api_service.dart';
import 'package:muslimku/core/state/mounted_flag.dart';
import 'package:muslimku/core/storage/content_cache.dart';
import 'package:muslimku/core/storage/local_store.dart';

/// Lists that each tab saves after the first visit; "Simpan" saves them all
/// at once from Pengaturan > Data offline. Keys are shared with the tabs.
class OfflineLists {
  static const doa = 'lists/doa.json';
  static const husna = 'lists/husna.json';
  static const arbain = 'lists/arbain.json';
  static const perawi = 'lists/perawi.json';
  static const all = [doa, husna, arbain, perawi];
}

class OfflineListsState {
  const OfflineListsState({
    this.saved = 0,
    this.bytes = 0,
    this.busy = false,
    this.error,
  });

  /// How many of [OfflineLists.all] are on the phone.
  final int saved;
  final int bytes;
  final bool busy;
  final String? error;

  bool get complete => saved >= OfflineLists.all.length;
}

final offlineListsProvider =
    NotifierProvider<OfflineListsNotifier, OfflineListsState>(
      OfflineListsNotifier.new,
    );

class OfflineListsNotifier extends Notifier<OfflineListsState> {
  @override
  OfflineListsState build() {
    _alive = MountedFlag(ref);
    refresh();
    return const OfflineListsState();
  }

  late MountedFlag _alive;

  Future<void> refresh() async {
    final store = ref.read(localStoreProvider);
    final keys = await store.keys('lists/');
    final bytes = await store.size('lists/');
    if (!_alive.mounted) return;
    state = OfflineListsState(
      saved: OfflineLists.all.where(keys.contains).length,
      bytes: bytes,
      busy: state.busy,
      error: state.error,
    );
  }

  Future<void> saveAll() async {
    if (state.busy) return;
    state = OfflineListsState(
      saved: state.saved,
      bytes: state.bytes,
      busy: true,
    );
    final api = ref.read(apiServiceProvider);
    final cache = ref.read(contentCacheProvider);
    final jobs = <String, Future<List<Map<String, dynamic>>?> Function()>{
      OfflineLists.doa: api.getAllDoa,
      OfflineLists.husna: api.getAllAsmaulHusna,
      OfflineLists.arbain: api.getAllHadithArbain,
      OfflineLists.perawi: api.getPerawiList,
    };
    var failed = false;
    for (final job in jobs.entries) {
      try {
        final result = await cache.list(job.key, job.value, refresh: true);
        if (result.offline) failed = true;
      } catch (_) {
        failed = true;
      }
    }
    if (!_alive.mounted) return;
    state = OfflineListsState(
      saved: state.saved,
      bytes: state.bytes,
      error: failed
          ? 'Sebagian belum tersimpan. Coba lagi saat ada internet.'
          : null,
    );
    await refresh();
  }
}

/// "±4,5 MB", "±170 KB".
String formatBytes(int bytes) {
  if (bytes >= 1024 * 1024) {
    final mb = bytes / (1024 * 1024);
    return '±${mb.toStringAsFixed(mb >= 10 ? 0 : 1).replaceAll('.', ',')} MB';
  }
  final kb = (bytes / 1024).ceil();
  return '±$kb KB';
}
