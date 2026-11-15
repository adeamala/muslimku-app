import 'package:intl/intl.dart';

/// A plan to finish the 30 juz by [target], starting on [start]; progress
/// comes from the juz marked finished (`khatamProvider`).
class KhatamPlan {
  KhatamPlan({required DateTime start, required DateTime target})
    : start = DateTime(start.year, start.month, start.day),
      target = DateTime(target.year, target.month, target.day);

  final DateTime start;
  final DateTime target;

  static const totalJuz = 30;

  /// (label, days). Ramadhan is counted as 29 days.
  static const presets = [
    ('30 hari', 30),
    ('Ramadhan', 29),
    ('60 hari', 60),
    ('90 hari', 90),
  ];

  static KhatamPlan preset(String label, {required DateTime today}) {
    final days = presets.firstWhere((p) => p.$1 == label).$2;
    return KhatamPlan(
      start: today,
      target: DateTime(today.year, today.month, today.day + days - 1),
    );
  }

  /// Calendar days from [start] to [target], both included.
  int get days => target.difference(start).inDays + 1;

  double get juzPerDay => totalJuz / days;

  /// "Khatam 24 Nov 2026".
  String get label =>
      'Khatam ${DateFormat('d MMM yyyy', 'id_ID').format(target)}';

  KhatamStatus status({required int doneJuz, required DateTime today}) {
    final day = DateTime(today.year, today.month, today.day);
    final dayNumber = day.difference(start).inDays + 1;
    final daysLeft = (target.difference(day).inDays + 1).clamp(0, days);
    final done = doneJuz.clamp(0, totalJuz);
    // Juz that should be finished by the end of today / yesterday.
    final expectedToday = (juzPerDay * dayNumber).ceil().clamp(1, totalJuz);
    final expectedYesterday = (juzPerDay * (dayNumber - 1)).floor().clamp(
      0,
      totalJuz,
    );
    final behind = (expectedYesterday - done).clamp(0, totalJuz);
    final ahead = (done - expectedToday).clamp(0, totalJuz);
    final left = totalJuz - done;
    final perDayNeeded = daysLeft == 0 ? left.toDouble() : left / daysLeft;
    final firstDue = done + 1;
    final lastDue = expectedToday < firstDue ? firstDue : expectedToday;
    return KhatamStatus(
      dayNumber: dayNumber,
      daysLeft: daysLeft,
      expectedJuz: expectedToday,
      behind: behind,
      ahead: ahead,
      perDayNeeded: perDayNeeded,
      finished: done >= totalJuz,
      left: left,
      todayTarget: done >= totalJuz
          ? 'Selesai'
          : lastDue == firstDue
          ? 'Juz $firstDue'
          : 'Juz $firstDue–$lastDue',
    );
  }

  Map<String, dynamic> toJson() => {
    'start': _iso(start),
    'target': _iso(target),
    'days': days,
  };

  static KhatamPlan? fromJson(Object? json) {
    if (json is! Map) return null;
    final start = DateTime.tryParse('${json['start']}');
    final target = DateTime.tryParse('${json['target']}');
    if (start == null || target == null || target.isBefore(start)) return null;
    return KhatamPlan(start: start, target: target);
  }

  static String _iso(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  bool operator ==(Object other) =>
      other is KhatamPlan && other.start == start && other.target == target;

  @override
  int get hashCode => Object.hash(start, target);
}

class KhatamStatus {
  const KhatamStatus({
    required this.dayNumber,
    required this.daysLeft,
    required this.expectedJuz,
    required this.behind,
    required this.ahead,
    required this.perDayNeeded,
    required this.finished,
    required this.left,
    required this.todayTarget,
  });

  final int dayNumber;
  final int daysLeft;

  /// Juz that should be finished by the end of today.
  final int expectedJuz;

  /// Juz short of the plan as of yesterday.
  final int behind;

  /// Juz beyond today's expectation.
  final int ahead;

  /// Juz per day needed from today to still make the target.
  final double perDayNeeded;
  final bool finished;
  final int left;

  /// "Juz 7–10", "Juz 1", or "Selesai".
  final String todayTarget;

  /// One line for the card.
  String get line {
    if (finished) return 'Khatam! 30 juz selesai';
    if (daysLeft == 0) return 'Lewat target · $left juz tersisa';
    if (behind > 0) {
      return 'Hari ke-$dayNumber · tertinggal $behind juz · '
          '${_perDay(perDayNeeded)} juz/hari';
    }
    if (ahead > 0) return 'Hari ke-$dayNumber · $ahead juz lebih cepat';
    return 'Hari ke-$dayNumber · target hari ini $todayTarget';
  }

  static String _perDay(double v) {
    final rounded = (v * 10).round() / 10;
    return rounded == rounded.roundToDouble()
        ? '${rounded.round()}'
        : rounded.toStringAsFixed(1).replaceAll('.', ',');
  }
}
