/// Number of the "Hadits hari ini": the day of the year walks through the
/// [count] Arbain hadiths (1 January is No. 1), the same for everyone.
int dailyArbainNumber(DateTime date, {int count = 42}) {
  if (count <= 0) return 1;
  final day = DateTime.utc(
    date.year,
    date.month,
    date.day,
  ).difference(DateTime.utc(date.year)).inDays;
  return day % count + 1;
}
