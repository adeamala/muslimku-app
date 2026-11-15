import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muslimku/core/state/mounted_flag.dart';
import 'package:muslimku/core/storage/local_store.dart';
import 'package:muslimku/features/prayer/domain/adzan_plan.dart'
    show AdzanPrayer;
import 'package:muslimku/features/prayer/domain/prayer_log.dart';

/// "Sudah sholat" marks, kept in `prayer_log.json` on the phone.
final prayerLogProvider = NotifierProvider<PrayerLogNotifier, PrayerLog>(
  PrayerLogNotifier.new,
);

class PrayerLogNotifier extends Notifier<PrayerLog> {
  static const storeKey = 'prayer_log.json';

  late LocalStore _store;
  late Future<void> ready;
  bool _touched = false;

  @override
  PrayerLog build() {
    _store = ref.watch(localStoreProvider);
    _touched = false;
    ready = _load(MountedFlag(ref));
    return PrayerLog.empty;
  }

  Future<void> _load(MountedFlag alive) async {
    try {
      final json = await _store.readJson(storeKey);
      if (_touched || !alive.mounted) return;
      state = PrayerLog.fromJson(json);
    } catch (_) {
      // A damaged file starts an empty log.
    }
  }

  Future<void> toggle(DateTime day, AdzanPrayer prayer) =>
      _update(state.toggle(day, prayer));

  Future<void> _update(PrayerLog next) async {
    _touched = true;
    state = next;
    try {
      await _store.writeJson(storeKey, next.toJson());
    } catch (_) {}
  }
}
