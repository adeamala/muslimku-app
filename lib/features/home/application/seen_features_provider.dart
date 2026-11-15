import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muslimku/core/state/mounted_flag.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Features the user has opened at least once, so their "BARU" badge can go.
/// `null` until the saved flags are loaded, so a badge never flashes.
final seenFeaturesProvider =
    NotifierProvider<SeenFeaturesNotifier, Set<String>?>(
      SeenFeaturesNotifier.new,
    );

class SeenFeaturesNotifier extends Notifier<Set<String>?> {
  @override
  Set<String>? build() {
    ready = _load(MountedFlag(ref));
    return null;
  }

  // 1.2.0: kiblat, tasbih (no longer badged). 1.4.0: the three below.
  static const kalender = 'kalender';
  static const catatan = 'catatan';
  static const jadwal = 'jadwal';
  static const all = [kalender, catatan, jadwal];

  static String keyFor(String feature) => 'seen_feature_$feature';

  late Future<void> ready;

  Future<void> _load(MountedFlag alive) async {
    final prefs = await SharedPreferences.getInstance();
    if (!alive.mounted) return;
    state = {
      ...?state,
      for (final f in all)
        if (prefs.getBool(keyFor(f)) ?? false) f,
    };
  }

  Future<void> markSeen(String feature) async {
    if (state?.contains(feature) ?? false) return;
    state = {...?state, feature};
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(keyFor(feature), true);
  }
}
