import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muslimku/core/state/mounted_flag.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Where the user stopped reading. Saved automatically by the reader.
class LastRead {
  const LastRead({
    required this.surah,
    required this.ayah,
    required this.surahName,
    required this.verseCount,
    required this.juz,
    required this.page,
    required this.updatedAt,
  });

  factory LastRead.fromJson(Map<String, dynamic> json) => LastRead(
    surah: json['surah'] as int,
    ayah: json['ayah'] as int,
    surahName: json['surahName'] as String? ?? '',
    verseCount: json['verseCount'] as int? ?? 0,
    juz: json['juz'] as int? ?? 0,
    page: json['page'] as int? ?? 0,
    updatedAt: DateTime.tryParse('${json['updatedAt']}') ?? DateTime(2026),
  );

  final int surah;
  final int ayah;
  final String surahName;
  final int verseCount;
  final int juz;
  final int page;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() => {
    'surah': surah,
    'ayah': ayah,
    'surahName': surahName,
    'verseCount': verseCount,
    'juz': juz,
    'page': page,
    'updatedAt': updatedAt.toIso8601String(),
  };

  /// 0–1 through the surah.
  double get progress => verseCount == 0 ? 0 : (ayah / verseCount).clamp(0, 1);
}

final lastReadProvider = NotifierProvider<LastReadNotifier, LastRead?>(
  LastReadNotifier.new,
);

class LastReadNotifier extends Notifier<LastRead?> {
  @override
  LastRead? build() {
    _touched = false;
    _alive = MountedFlag(ref);
    ready = _load(_alive);
    return null;
  }

  late MountedFlag _alive;

  /// False once the provider is disposed; the reader checks it before saving
  /// from its own dispose.
  bool get mounted => _alive.mounted;

  static const key = 'quran_last_read';
  late Future<void> ready;
  bool _touched = false;

  Future<void> _load(MountedFlag alive) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (_touched || !alive.mounted || raw == null) return;
    try {
      state = LastRead.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {}
  }

  Future<void> save(LastRead value) async {
    _touched = true;
    state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(value.toJson()));
  }
}

/// A marked ayah ("Ditandai").
class AyahBookmark {
  const AyahBookmark({
    required this.surah,
    required this.ayah,
    required this.surahName,
    required this.snippet,
    required this.savedAt,
  });

  factory AyahBookmark.fromJson(Map<String, dynamic> json) => AyahBookmark(
    surah: json['surah'] as int,
    ayah: json['ayah'] as int,
    surahName: json['surahName'] as String? ?? '',
    snippet: json['snippet'] as String? ?? '',
    savedAt: DateTime.tryParse('${json['savedAt']}') ?? DateTime(2026),
  );

  final int surah;
  final int ayah;
  final String surahName;

  /// Start of the translation, shown in the list.
  final String snippet;
  final DateTime savedAt;

  String get key => '$surah:$ayah';

  Map<String, dynamic> toJson() => {
    'surah': surah,
    'ayah': ayah,
    'surahName': surahName,
    'snippet': snippet,
    'savedAt': savedAt.toIso8601String(),
  };
}

/// Newest first.
final ayahBookmarksProvider =
    NotifierProvider<AyahBookmarksNotifier, List<AyahBookmark>>(
      AyahBookmarksNotifier.new,
    );

class AyahBookmarksNotifier extends Notifier<List<AyahBookmark>> {
  @override
  List<AyahBookmark> build() {
    _touched = false;
    ready = _load(MountedFlag(ref));
    return const [];
  }

  static const key = 'quran_bookmarks';
  late Future<void> ready;
  bool _touched = false;

  Future<void> _load(MountedFlag alive) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (_touched || !alive.mounted || raw == null) return;
    try {
      state = [
        for (final item in jsonDecode(raw) as List)
          AyahBookmark.fromJson(Map<String, dynamic>.from(item as Map)),
      ];
    } catch (_) {}
  }

  bool contains(int surah, int ayah) =>
      state.any((b) => b.surah == surah && b.ayah == ayah);

  /// Adds the ayah, or removes it when it is already marked. Returns true when added.
  bool toggle(AyahBookmark bookmark) {
    final exists = contains(bookmark.surah, bookmark.ayah);
    _set(
      exists
          ? state.where((b) => b.key != bookmark.key).toList()
          : [bookmark, ...state],
    );
    return !exists;
  }

  void remove(int surah, int ayah) =>
      _set(state.where((b) => !(b.surah == surah && b.ayah == ayah)).toList());

  Future<void> _set(List<AyahBookmark> next) async {
    _touched = true;
    state = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode([for (final b in next) b.toJson()]));
  }
}

/// Juz read to the end, for "Progres khatam".
final khatamProvider = NotifierProvider<KhatamNotifier, Set<int>>(
  KhatamNotifier.new,
);

class KhatamNotifier extends Notifier<Set<int>> {
  @override
  Set<int> build() {
    _touched = false;
    ready = _load(MountedFlag(ref));
    return const {};
  }

  static const key = 'quran_khatam_juz';
  late Future<void> ready;
  bool _touched = false;

  Future<void> _load(MountedFlag alive) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(key);
    if (_touched || !alive.mounted || saved == null) return;
    state = {for (final s in saved) ?int.tryParse(s)};
  }

  void markDone(int juz) {
    if (juz < 1 || juz > 30 || state.contains(juz)) return;
    _set({...state, juz});
  }

  void unmark(int juz) => _set({...state}..remove(juz));

  void reset() => _set(const {});

  Future<void> _set(Set<int> next) async {
    _touched = true;
    state = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(key, [
      for (final j in next.toList()..sort()) '$j',
    ]);
  }
}
