import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muslimku/core/state/mounted_flag.dart';
import 'package:muslimku/features/prayer/domain/adzan_plan.dart'
    show AdzanPrayer;
import 'package:muslimku/features/prayer/domain/prayer_offsets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Per-prayer minute corrections, saved on the phone. Beranda, the adzan plan
/// and Jadwal sebulan all read the schedule through [PrayerOffsets.apply].
final prayerOffsetsProvider =
    NotifierProvider<PrayerOffsetsNotifier, PrayerOffsets>(
      PrayerOffsetsNotifier.new,
    );

class PrayerOffsetsNotifier extends Notifier<PrayerOffsets> {
  @override
  PrayerOffsets build() {
    _touched = false;
    ready = _load(MountedFlag(ref));
    return PrayerOffsets.none;
  }

  static const key = 'prayer_offsets';

  late Future<void> ready;
  bool _touched = false;

  Future<void> _load(MountedFlag alive) async {
    final prefs = await SharedPreferences.getInstance();
    if (_touched || !alive.mounted) return;
    state = PrayerOffsets.fromJson(prefs.getString(key));
  }

  Future<void> set(AdzanPrayer prayer, int minutes) =>
      _update(state.set(prayer, minutes));

  Future<void> reset() => _update(PrayerOffsets.none);

  Future<void> _update(PrayerOffsets next) async {
    _touched = true;
    state = next;
    final prefs = await SharedPreferences.getInstance();
    if (next.isZero) {
      await prefs.remove(key);
    } else {
      await prefs.setString(key, next.toJson());
    }
  }
}
