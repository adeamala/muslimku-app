import 'package:muslimku/features/prayer/domain/prayer_time_model.dart';

/// One of the six times shown on the home timeline.
class TimelineEntry {
  const TimelineEntry({
    required this.label,
    required this.time,
    required this.isPrayer,
  });

  final String label;

  /// `HH:mm` as sent by MyQuran.
  final String time;

  /// Terbit (sunrise) is shown for orientation but is not a prayer.
  final bool isPrayer;
}

enum TimelineState { passed, next, upcoming }

class NextPrayer {
  const NextPrayer({
    required this.label,
    required this.time,
    required this.at,
    required this.isTomorrow,
  });

  final String label;
  final String time;
  final DateTime at;

  /// True after Isya, when the next prayer is tomorrow's Subuh.
  final bool isTomorrow;

  Duration remaining(DateTime now) => at.difference(now);
}

List<TimelineEntry> homeTimeline(PrayerSchedule s) => [
  TimelineEntry(label: 'Subuh', time: s.subuh, isPrayer: true),
  TimelineEntry(label: 'Terbit', time: s.terbit, isPrayer: false),
  TimelineEntry(label: 'Dzuhur', time: s.dzuhur, isPrayer: true),
  TimelineEntry(label: 'Ashar', time: s.ashar, isPrayer: true),
  TimelineEntry(label: 'Maghrib', time: s.maghrib, isPrayer: true),
  TimelineEntry(label: 'Isya', time: s.isya, isPrayer: true),
];

/// `HH:mm` on the same calendar day as [day], or null if it does not parse.
DateTime? timeOnDay(DateTime day, String hhmm) {
  final parts = hhmm.trim().split(':');
  if (parts.length < 2) return null;
  final h = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  if (h == null || m == null || h > 23 || m > 59) return null;
  return DateTime(day.year, day.month, day.day, h, m);
}

/// The first prayer after [now]. A prayer counts as started at its minute.
/// After Isya this is tomorrow's Subuh, estimated from today's time
/// (it moves by about a minute a day).
NextPrayer? findNextPrayer(PrayerSchedule schedule, DateTime now) {
  final entries = homeTimeline(schedule).where((e) => e.isPrayer);
  for (final e in entries) {
    final at = timeOnDay(now, e.time);
    if (at != null && now.isBefore(at)) {
      return NextPrayer(
        label: e.label,
        time: e.time,
        at: at,
        isTomorrow: false,
      );
    }
  }
  final subuh = timeOnDay(now, schedule.subuh);
  if (subuh == null) return null;
  return NextPrayer(
    label: 'Subuh',
    time: schedule.subuh,
    at: DateTime(
      subuh.year,
      subuh.month,
      subuh.day + 1,
      subuh.hour,
      subuh.minute,
    ),
    isTomorrow: true,
  );
}

List<TimelineState> timelineStates(
  List<TimelineEntry> entries,
  DateTime now,
  NextPrayer? next,
) {
  return [
    for (final e in entries)
      if (next != null && !next.isTomorrow && e.label == next.label)
        TimelineState.next
      else if (_hasPassed(e, now))
        TimelineState.passed
      else
        TimelineState.upcoming,
  ];
}

bool _hasPassed(TimelineEntry e, DateTime now) {
  final at = timeOnDay(now, e.time);
  return at != null && !now.isBefore(at);
}

/// "38 menit lagi", "1 jam 5 menit lagi". Minutes round up so the label never
/// says "0 menit".
String countdownLabel(Duration remaining) {
  if (remaining.inSeconds < 60) return 'Kurang dari 1 menit lagi';
  final totalMinutes = (remaining.inSeconds / 60).ceil();
  final hours = totalMinutes ~/ 60;
  final minutes = totalMinutes % 60;
  if (hours == 0) return '$minutes menit lagi';
  if (minutes == 0) return '$hours jam lagi';
  return '$hours jam $minutes menit lagi';
}

/// MyQuran names cities in upper case ("KOTA KEDIRI").
String titleCaseCity(String name) {
  return name
      .trim()
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .map((w) => w[0].toUpperCase() + w.substring(1).toLowerCase())
      .join(' ');
}
