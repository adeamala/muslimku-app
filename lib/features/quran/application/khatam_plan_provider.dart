import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muslimku/core/state/mounted_flag.dart';
import 'package:muslimku/features/quran/domain/khatam_plan.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The current khatam plan, or null when none is set. Saved as `khatam_plan`.
final khatamPlanProvider = NotifierProvider<KhatamPlanNotifier, KhatamPlan?>(
  KhatamPlanNotifier.new,
);

class KhatamPlanNotifier extends Notifier<KhatamPlan?> {
  @override
  KhatamPlan? build() {
    _touched = false;
    ready = _load(MountedFlag(ref));
    return null;
  }

  static const key = 'khatam_plan';

  late Future<void> ready;
  bool _touched = false;

  Future<void> _load(MountedFlag alive) async {
    final prefs = await SharedPreferences.getInstance();
    if (_touched || !alive.mounted) return;
    final raw = prefs.getString(key);
    if (raw == null) return;
    try {
      state = KhatamPlan.fromJson(jsonDecode(raw));
    } catch (_) {
      state = null;
    }
  }

  Future<void> set(KhatamPlan plan) async {
    _touched = true;
    state = plan;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(plan.toJson()));
  }

  Future<void> clear() async {
    _touched = true;
    state = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }
}
