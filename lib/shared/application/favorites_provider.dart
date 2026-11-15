import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muslimku/core/state/mounted_flag.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Favourite / marked items per area, saved on the phone.
///
/// Namespaces in use: `doa` (keys = doa title), `hadits` (keys like
/// `arbain:16`, `bm:12`, `bukhari:52`), `husna` (keys = number).
final favoritesProvider =
    NotifierProvider.family<FavoritesNotifier, Set<String>, String>(
      FavoritesNotifier.new,
    );

class FavoritesNotifier extends FamilyNotifier<Set<String>, String> {
  @override
  Set<String> build(String namespace) {
    _touched = false;
    ready = _load(MountedFlag(ref));
    return const {};
  }

  String get namespace => arg;
  late Future<void> ready;
  bool _touched = false;

  String get _key => 'favorites_$namespace';

  Future<void> _load(MountedFlag alive) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_key);
    if (_touched || !alive.mounted || saved == null) return;
    state = saved.toSet();
  }

  /// Returns true when the item is now a favourite.
  bool toggle(String key) {
    final next = {...state};
    final added = next.add(key);
    if (!added) next.remove(key);
    _set(next);
    return added;
  }

  Future<void> _set(Set<String> next) async {
    _touched = true;
    state = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, next.toList());
  }
}
