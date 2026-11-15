import 'package:muslimku/features/prayer/domain/adzan_plan.dart'
    show AdzanPrayer;

/// Which obligatory prayers were marked done on which day. Stored on the
/// phone only; a day counts for the streak when all five are marked.
class PrayerLog {
  const PrayerLog(this._days);

  static const empty = PrayerLog({});

  /// yyyy-mm-dd → prayers done that day (never empty sets).
  final Map<String, Set<AdzanPrayer>> _days;

  static String key(DateTime day) =>
      '${day.year}-${_two(day.month)}-${_two(day.day)}';

  static String _two(int n) => n.toString().padLeft(2, '0');

  Set<AdzanPrayer> doneOn(DateTime day) =>
      Set.unmodifiable(_days[key(day)] ?? const <AdzanPrayer>{});

  bool isDone(DateTime day, AdzanPrayer prayer) =>
      _days[key(day)]?.contains(prayer) ?? false;

  int countOn(DateTime day) => _days[key(day)]?.length ?? 0;

  bool isComplete(DateTime day) => countOn(day) == AdzanPrayer.values.length;

  PrayerLog toggle(DateTime day, AdzanPrayer prayer) {
    final done = {...doneOn(day)};
    if (!done.remove(prayer)) done.add(prayer);
    return setDay(day, done);
  }

  PrayerLog setDay(DateTime day, Set<AdzanPrayer> done) {
    final next = Map<String, Set<AdzanPrayer>>.from(_days);
    if (done.isEmpty) {
      next.remove(key(day));
    } else {
      next[key(day)] = Set.unmodifiable(done);
    }
    return PrayerLog(next);
  }

  /// Complete days in a row ending today, or ending yesterday while today is
  /// still open; 0 once yesterday was missed.
  int currentStreak(DateTime today) {
    final start = DateTime(today.year, today.month, today.day);
    var day = isComplete(start)
        ? start
        : start.subtract(const Duration(days: 1));
    var count = 0;
    while (isComplete(day)) {
      count++;
      day = day.subtract(const Duration(days: 1));
    }
    return count;
  }

  /// The longest run of complete days on record, up to [today].
  int longestStreak(DateTime today) {
    final days = _days.keys.toList()..sort();
    var best = 0;
    var run = 0;
    DateTime? previous;
    for (final k in days) {
      final day = DateTime.parse(k);
      if (day.isAfter(today)) break;
      if (!isComplete(day)) {
        run = 0;
        previous = day;
        continue;
      }
      run = previous != null && day.difference(previous).inDays == 1
          ? run + 1
          : 1;
      previous = day;
      if (run > best) best = run;
    }
    return best;
  }

  /// (day, prayers done) for the [count] days ending [today], oldest first.
  List<(DateTime, int)> lastDays(DateTime today, int count) {
    final start = DateTime(today.year, today.month, today.day);
    return [
      for (var i = count - 1; i >= 0; i--)
        (
          start.subtract(Duration(days: i)),
          countOn(start.subtract(Duration(days: i))),
        ),
    ];
  }

  Map<String, dynamic> toJson() => {
    for (final e in _days.entries) e.key: [for (final p in e.value) p.name],
  };

  static PrayerLog fromJson(Object? json) {
    if (json is! Map) return empty;
    final days = <String, Set<AdzanPrayer>>{};
    for (final e in json.entries) {
      final names = e.value;
      if (names is! List) continue;
      final set = {
        for (final n in names)
          for (final p in AdzanPrayer.values)
            if (p.name == n) p,
      };
      if (set.isNotEmpty) days['${e.key}'] = Set.unmodifiable(set);
    }
    return PrayerLog(days);
  }
}
