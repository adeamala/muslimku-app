import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muslimku/core/network/api_service.dart';
import 'package:muslimku/core/state/mounted_flag.dart';
import 'package:muslimku/core/storage/content_cache.dart';
import 'package:muslimku/core/utils/arabic_text.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// One doa from MyQuran `doa/semua` (108 items, no latin).
class Doa {
  const Doa({
    required this.title,
    required this.arabic,
    required this.meaning,
    required this.category,
  });

  /// MyQuran sends the text as `doa` and the meaning as `artinya` (older
  /// endpoints used `arab`/`indo`), and `source` holds the category.
  factory Doa.fromJson(Map<String, dynamic> json) {
    final category = cleanDoaText(json['source']).toLowerCase();
    return Doa(
      title: cleanDoaText(json['judul']),
      arabic: normalizeQuranText(cleanDoaText(_first(json, 'doa', 'arab'))),
      meaning: cleanDoaText(_first(json, 'artinya', 'indo')),
      category: category.isEmpty ? 'lainnya' : category,
    );
  }

  final String title;
  final String arabic;
  final String meaning;

  /// MyQuran `source`: harian, quran, haji, hadits, lainnya, ibadah, pilihan.
  final String category;

  /// Key in `favoritesProvider('doa')`: the (cleaned) title.
  String get key => title;

  String get categoryLabel => doaCategoryLabel(category);

  /// Plain text for sharing.
  String get shareText =>
      '$title\n\n$arabic\n\nArtinya: $meaning\n\nDibagikan dari aplikasi Muslimku';
}

Object? _first(Map<String, dynamic> json, String key, String fallback) {
  final value = '${json[key] ?? ''}'.trim();
  return value.isNotEmpty ? value : json[fallback];
}

/// MyQuran texts carry line breaks from the printed source (`\r\n` mid
/// sentence, sometimes as literal backslash text): join them into one line.
String cleanDoaText(Object? value) => '${value ?? ''}'
    .replaceAll(RegExp(r'\\[rn]'), '\n')
    .replaceAll(RegExp(r'-[ \t]*[\r\n]\s*'), '-')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

const _categoryLabels = {
  'harian': 'Harian',
  'quran': "Al-Qur'an",
  'haji': 'Haji',
  'hadits': 'Hadits',
  'lainnya': 'Lainnya',
  'ibadah': 'Ibadah',
  'pilihan': 'Pilihan',
};

String doaCategoryLabel(String category) {
  final known = _categoryLabels[category];
  if (known != null) return known;
  if (category.isEmpty) return 'Lainnya';
  return category[0].toUpperCase() + category.substring(1);
}

class DoaCategory {
  const DoaCategory(this.key, this.count);

  final String key;
  final int count;

  String get label => doaCategoryLabel(key);
}

/// Categories by size (largest first); equal sizes keep the data order.
List<DoaCategory> doaCategories(List<Doa> all) {
  final counts = <String, int>{};
  for (final doa in all) {
    counts[doa.category] = (counts[doa.category] ?? 0) + 1;
  }
  final order = counts.keys.toList();
  final keys = [...order]
    ..sort((a, b) {
      final bySize = counts[b]!.compareTo(counts[a]!);
      return bySize != 0 ? bySize : order.indexOf(a) - order.indexOf(b);
    });
  return [for (final key in keys) DoaCategory(key, counts[key]!)];
}

/// Doa in [category] (all when null) whose title or meaning contains [query],
/// ignoring case.
List<Doa> filterDoa(List<Doa> all, {String? category, String query = ''}) {
  final q = query.trim().toLowerCase();
  return [
    for (final doa in all)
      if ((category == null || doa.category == category) &&
          (q.isEmpty ||
              doa.title.toLowerCase().contains(q) ||
              doa.meaning.toLowerCase().contains(q)))
        doa,
  ];
}

/// The doa saved as favourites, newest first (keys are kept in the order they
/// were added). Keys of doa that no longer exist are skipped.
List<Doa> favouriteDoas(List<Doa> all, Iterable<String> keys) {
  final byKey = {for (final doa in all) doa.key: doa};
  return [
    for (final key in keys.toList().reversed)
      if (byKey[key] != null) byKey[key]!,
  ];
}

/// Bumped by "Coba lagi" and pull-to-refresh: from then on the list asks
/// MyQuran first instead of using a saved copy that is still fresh.
final doaRefreshProvider = StateProvider<int>((ref) => 0);

/// All doa, network-first with a saved copy (`lists/doa.json`).
final doaListProvider = FutureProvider<Cached<List<Doa>>>((ref) async {
  final refresh = ref.watch(doaRefreshProvider) > 0;
  final api = ref.watch(apiServiceProvider);
  final cached = await ref
      .watch(contentCacheProvider)
      .list('lists/doa.json', api.getAllDoa, refresh: refresh);
  return cached.map(
    (items) => [
      for (final item in items)
        if ('${item['judul'] ?? ''}'.trim().isNotEmpty) Doa.fromJson(item),
    ],
  );
});

/// Keeps the screen on (wakelock_plus). Tests swap it for a fake.
class ScreenWake {
  const ScreenWake();

  Future<void> enable() async {
    try {
      await WakelockPlus.enable();
    } catch (_) {
      // Not supported on this platform.
    }
  }

  Future<void> disable() async {
    try {
      await WakelockPlus.disable();
    } catch (_) {}
  }
}

final screenWakeProvider = Provider<ScreenWake>((ref) => const ScreenWake());

/// "Layar tetap menyala" on the doa page, saved on the phone.
final doaKeepAwakeProvider = NotifierProvider<DoaKeepAwakeNotifier, bool>(
  DoaKeepAwakeNotifier.new,
);

class DoaKeepAwakeNotifier extends Notifier<bool> {
  @override
  bool build() {
    _touched = false;
    ready = _load(MountedFlag(ref));
    return false;
  }

  static const prefsKey = 'doa_keep_awake';

  late Future<void> ready;
  bool _touched = false;

  Future<void> _load(MountedFlag alive) async {
    final prefs = await SharedPreferences.getInstance();
    if (_touched || !alive.mounted) return;
    state = prefs.getBool(prefsKey) ?? false;
  }

  Future<void> set(bool value) async {
    _touched = true;
    state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(prefsKey, value);
  }
}
