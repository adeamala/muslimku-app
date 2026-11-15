import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muslimku/core/state/mounted_flag.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Hijri date correction in days (−1, 0, +1), for when rukyat lands a day
/// away from the arithmetic calendar.
final hijriAdjustProvider = NotifierProvider<HijriAdjustNotifier, int>(
  HijriAdjustNotifier.new,
);

class HijriAdjustNotifier extends Notifier<int> {
  @override
  int build() {
    _touched = false;
    ready = _load(MountedFlag(ref));
    return 0;
  }

  static const key = 'hijri_adjust';

  late Future<void> ready;
  bool _touched = false;

  Future<void> _load(MountedFlag alive) async {
    final prefs = await SharedPreferences.getInstance();
    if (_touched || !alive.mounted) return;
    state = (prefs.getInt(key) ?? 0).clamp(-1, 1);
  }

  Future<void> set(int days) async {
    _touched = true;
    state = days.clamp(-1, 1);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(key, state);
  }
}
