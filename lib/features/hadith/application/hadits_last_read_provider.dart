import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muslimku/core/state/mounted_flag.dart';
import 'package:muslimku/features/hadith/domain/hadith_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The last hadith number opened per perawi (`bukhari` → 52), saved on the
/// phone, so a perawi tile continues where the reader stopped.
final perawiLastNumberProvider =
    NotifierProvider<PerawiLastNumbers, Map<String, int>>(
      PerawiLastNumbers.new,
    );

class PerawiLastNumbers extends Notifier<Map<String, int>> {
  @override
  Map<String, int> build() {
    ready = _load(MountedFlag(ref));
    return const {};
  }

  static String prefsKey(String slug) => 'hadits_last_$slug';

  late Future<void> ready;

  Future<void> _load(MountedFlag alive) async {
    final prefs = await SharedPreferences.getInstance();
    if (!alive.mounted) return;
    final saved = <String, int>{
      for (final book in HaditsBook.perawi)
        if (prefs.getInt(prefsKey(book.slug)) case final number?)
          book.slug: number,
    };
    // Numbers remembered while loading win over the saved ones.
    state = {...saved, ...state};
  }

  /// Where a perawi tile opens: the last number, or No. 1.
  int numberFor(String slug) => state[slug] ?? 1;

  void remember(String slug, int number) {
    if (state[slug] == number) return;
    state = {...state, slug: number};
    SharedPreferences.getInstance().then(
      (prefs) => prefs.setInt(prefsKey(slug), number),
    );
  }
}
