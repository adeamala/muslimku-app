import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muslimku/core/network/api_service.dart';

import 'package:muslimku/core/storage/content_cache.dart';

/// One of the 99 names from MyQuran `husna/semua`.
class HusnaName {
  const HusnaName({
    required this.number,
    required this.arabic,
    required this.latin,
    required this.meaning,
  });

  factory HusnaName.fromJson(Map<String, dynamic> json) => HusnaName(
    number: _asInt(json['id']),
    arabic: _text(json['arab']),
    latin: _text(json['latin']),
    meaning: _text(json['indo']),
  );

  final int number;
  final String arabic;
  final String latin;
  final String meaning;

  /// Plain text for sharing.
  String get shareText =>
      '$arabic\n$latin: $meaning\n(Asmaul Husna ke-$number)\n\n'
      'Dibagikan dari aplikasi Muslimku';
}

/// MyQuran sends numbers as int or string.
int _asInt(Object? value) =>
    value is int ? value : int.tryParse('${value ?? ''}'.trim()) ?? 0;

String _text(Object? value) =>
    '${value ?? ''}'.replaceAll(RegExp(r'\s+'), ' ').trim();

/// "Nama hari ini": the names in turn by day of the year (1 January is the
/// first name), so everyone sees the same name on the same day.
HusnaName nameOfTheDay(List<HusnaName> names, DateTime day) {
  final dayOfYear = DateTime.utc(
    day.year,
    day.month,
    day.day,
  ).difference(DateTime.utc(day.year)).inDays;
  return names[dayOfYear % names.length];
}

/// Bumped by "Coba lagi" and pull-to-refresh: from then on the list asks
/// MyQuran first instead of using a saved copy that is still fresh.
final husnaRefreshProvider = StateProvider<int>((ref) => 0);

/// The 99 names by number, network-first with a saved copy
/// (`lists/husna.json`).
final husnaListProvider = FutureProvider<Cached<List<HusnaName>>>((ref) async {
  final refresh = ref.watch(husnaRefreshProvider) > 0;
  final api = ref.watch(apiServiceProvider);
  final cached = await ref
      .watch(contentCacheProvider)
      .list('lists/husna.json', api.getAllAsmaulHusna, refresh: refresh);
  return cached.map(
    (items) =>
        [for (final item in items) HusnaName.fromJson(item)]
          ..sort((a, b) => a.number.compareTo(b.number)),
  );
});
