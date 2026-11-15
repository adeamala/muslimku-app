/// Tabular (arithmetic) Islamic calendar, the 30-year cycle with leap years
/// 2, 5, 7, 10, 13, 16, 18, 21, 24, 26 and 29. It matches the Indonesian
/// calendar on the checked years; rukyat can still move a month by a day,
/// which the ±1 correction in Pengaturan covers.
class HijriDate {
  const HijriDate(this.year, this.month, this.day);

  final int year;

  /// 1 = Muharram … 12 = Dzulhijjah.
  final int month;
  final int day;

  static const monthNames = [
    'Muharram',
    'Safar',
    'Rabiul Awal',
    'Rabiul Akhir',
    'Jumadil Awal',
    'Jumadil Akhir',
    'Rajab',
    "Sya'ban",
    'Ramadhan',
    'Syawal',
    "Dzulqa'dah",
    'Dzulhijjah',
  ];

  /// Rata Die of 1 Muharram 1 H (19 July 622, proleptic Gregorian).
  static const _epoch = 227015;

  /// Days from 1 January 1 (RD 1) to [date], at local midnight.
  static int _rd(DateTime date) =>
      DateTime.utc(
        date.year,
        date.month,
        date.day,
      ).difference(DateTime.utc(1, 1, 1)).inDays +
      1;

  static int _fixed(int y, int m, int d) =>
      _epoch -
      1 +
      (y - 1) * 354 +
      (3 + 11 * y) ~/ 30 +
      29 * (m - 1) +
      m ~/ 2 +
      d;

  static bool isLeapYear(int year) => (14 + 11 * year) % 30 < 11;

  /// [adjust] moves the Hijri date by that many days (−1, 0, +1).
  factory HijriDate.fromDate(DateTime date, {int adjust = 0}) {
    final rd = _rd(date) + adjust;
    final y = (30 * (rd - _epoch) + 10646) ~/ 10631;
    final prior = rd - _fixed(y, 1, 1);
    final m = (11 * prior + 330) ~/ 325;
    final d = rd - _fixed(y, m, 1) + 1;
    return HijriDate(y, m, d);
  }

  /// Local midnight of this Hijri day; [adjust] as in [fromDate].
  DateTime toDate({int adjust = 0}) {
    final rd = _fixed(year, month, day) - adjust;
    return DateTime(1, 1, 1).add(Duration(days: rd - 1));
  }

  int get daysInMonth =>
      month.isOdd || (month == 12 && isLeapYear(year)) ? 30 : 29;

  String get monthName => monthNames[month - 1];

  /// "13 Jumadil Awal 1448 H".
  String get label => '$day $monthName $year H';

  /// "Jumadil Awal 1448".
  String get monthLabel => '$monthName $year';

  HijriDate get firstOfMonth => HijriDate(year, month, 1);

  HijriDate addMonths(int n) {
    final index = year * 12 + (month - 1) + n;
    return HijriDate(index ~/ 12, index % 12 + 1, 1);
  }

  @override
  bool operator ==(Object other) =>
      other is HijriDate &&
      other.year == year &&
      other.month == month &&
      other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() => label;
}

/// A day of the Islamic year worth a mark on the calendar.
class IslamicEvent {
  const IslamicEvent(this.month, this.day, this.name, {this.note});

  final int month;
  final int day;
  final String name;

  /// Short line under the name, e.g. the sunnah of the day.
  final String? note;
}

const islamicEvents = [
  IslamicEvent(1, 1, 'Tahun Baru Islam', note: '1 Muharram'),
  IslamicEvent(1, 10, 'Asyura', note: 'Puasa sunnah 9–10 Muharram'),
  IslamicEvent(3, 12, 'Maulid Nabi', note: '12 Rabiul Awal'),
  IslamicEvent(7, 27, 'Isra Mikraj', note: '27 Rajab'),
  IslamicEvent(8, 15, 'Nisfu Syaban', note: "15 Sya'ban"),
  IslamicEvent(9, 1, 'Awal Ramadhan', note: 'Puasa wajib dimulai'),
  IslamicEvent(9, 17, 'Nuzulul Quran', note: '17 Ramadhan'),
  IslamicEvent(10, 1, 'Idul Fitri', note: '1 Syawal'),
  IslamicEvent(
    12,
    9,
    'Hari Arafah',
    note: 'Puasa sunnah bagi yang tidak berhaji',
  ),
  IslamicEvent(12, 10, 'Idul Adha', note: '10 Dzulhijjah'),
  IslamicEvent(
    12,
    11,
    'Hari Tasyrik',
    note: '11–13 Dzulhijjah, tidak berpuasa',
  ),
];

IslamicEvent? eventOn(HijriDate date) => islamicEvents
    .where((e) => e.month == date.month && e.day == date.day)
    .firstOrNull;

/// 13–15 of every month: the sunnah "white days" fast.
bool isAyyamulBidh(HijriDate date) => date.day >= 13 && date.day <= 15;

class UpcomingEvent {
  const UpcomingEvent(this.event, this.hijri, this.date, this.daysLeft);

  final IslamicEvent event;
  final HijriDate hijri;
  final DateTime date;
  final int daysLeft;
}

/// The next [count] events on or after [from], with the Gregorian date
/// under the current correction.
List<UpcomingEvent> upcomingEvents(
  DateTime from, {
  int adjust = 0,
  int count = 6,
}) {
  final start = DateTime(from.year, from.month, from.day);
  final year = HijriDate.fromDate(start, adjust: adjust).year;
  final out = <UpcomingEvent>[];
  for (var y = year; out.length < count && y <= year + 2; y++) {
    for (final e in islamicEvents) {
      final h = HijriDate(y, e.month, e.day);
      final date = h.toDate(adjust: adjust);
      final left = date.difference(start).inDays;
      if (left < 0) continue;
      out.add(UpcomingEvent(e, h, date, left));
    }
  }
  out.sort((a, b) => a.daysLeft.compareTo(b.daysLeft));
  return out.take(count).toList();
}
