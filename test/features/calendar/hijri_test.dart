import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:muslimku/core/time/clock_provider.dart';
import 'package:muslimku/features/calendar/application/hijri_provider.dart';
import 'package:muslimku/features/calendar/domain/hijri.dart';
import 'package:muslimku/features/calendar/presentation/hijri_calendar_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/pump_home.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => initializeDateFormatting('id_ID', null));
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('tabular conversion matches the Indonesian calendar on known days', () {
    HijriDate h(int y, int m, int d) => HijriDate.fromDate(DateTime(y, m, d));
    expect(h(622, 7, 19), const HijriDate(1, 1, 1));
    expect(h(2024, 3, 11), const HijriDate(1445, 9, 1)); // 1 Ramadhan 1445
    expect(h(2024, 4, 10), const HijriDate(1445, 10, 1)); // Idul Fitri 1445
    expect(h(2025, 3, 1), const HijriDate(1446, 9, 1)); // 1 Ramadhan 1446
    expect(h(2025, 6, 27), const HijriDate(1447, 1, 1)); // 1 Muharram 1447
    expect(h(2026, 10, 25), const HijriDate(1448, 5, 13));
    expect(h(2027, 2, 8), const HijriDate(1448, 9, 1)); // 1 Ramadhan 1448
    expect(h(2026, 10, 25).label, '13 Jumadil Awal 1448 H');
    expect(const HijriDate(1448, 9, 1).toDate(), DateTime(2027, 2, 8));
    expect(const HijriDate(1448, 5, 13).monthName, 'Jumadil Awal');
    expect(HijriDate.monthNames.length, 12);
    expect(HijriDate.monthNames.last, 'Dzulhijjah');
  });

  test('days in month, leap years and day-by-day continuity', () {
    expect(const HijriDate(1448, 1, 1).daysInMonth, 30);
    expect(const HijriDate(1448, 2, 1).daysInMonth, 29);
    expect(HijriDate.isLeapYear(1447), isTrue);
    expect(const HijriDate(1447, 12, 1).daysInMonth, 30);
    expect(HijriDate.isLeapYear(1448), isFalse);
    expect(const HijriDate(1448, 12, 1).daysInMonth, 29);
    var previous = HijriDate.fromDate(DateTime(2020, 1, 1));
    for (var i = 1; i < 366 * 12; i++) {
      final h = HijriDate.fromDate(DateTime(2020, 1, 1 + i));
      final next = previous.day < previous.daysInMonth
          ? HijriDate(previous.year, previous.month, previous.day + 1)
          : previous.month < 12
          ? HijriDate(previous.year, previous.month + 1, 1)
          : HijriDate(previous.year + 1, 1, 1);
      expect(h, next, reason: '${DateTime(2020, 1, 1 + i)}');
      expect(h.toDate(), DateTime(2020, 1, 1 + i));
      previous = h;
    }
  });

  test('the ±1 day correction shifts the date, never the Gregorian day', () {
    final day = DateTime(2026, 10, 25);
    expect(HijriDate.fromDate(day, adjust: 1).day, 14);
    expect(HijriDate.fromDate(day, adjust: -1).day, 12);
    expect(
      HijriDate.fromDate(DateTime(2027, 2, 8), adjust: -1).label,
      '29 Sya\'ban 1448 H',
    );
    expect(
      const HijriDate(1448, 9, 1).toDate(adjust: -1),
      DateTime(2027, 2, 9),
    );
  });

  test('important days, upcoming from a date', () {
    expect(
      islamicEvents.map((e) => e.name),
      containsAll([
        'Tahun Baru Islam',
        'Asyura',
        'Maulid Nabi',
        'Isra Mikraj',
        'Nisfu Syaban',
        'Awal Ramadhan',
        'Nuzulul Quran',
        'Idul Fitri',
        'Hari Arafah',
        'Idul Adha',
      ]),
    );
    final up = upcomingEvents(DateTime(2026, 10, 25), count: 4);
    expect(up.map((e) => e.event.name).toList(), [
      'Isra Mikraj',
      'Nisfu Syaban',
      'Awal Ramadhan',
      'Nuzulul Quran',
    ]);
    expect(up[2].date, DateTime(2027, 2, 8));
    expect(up[2].daysLeft, 106);
    expect(upcomingEvents(DateTime(2027, 2, 8), count: 1).first.daysLeft, 0);
    expect(eventOn(const HijriDate(1448, 10, 1))?.name, 'Idul Fitri');
    expect(eventOn(const HijriDate(1448, 10, 2)), isNull);
    // Sunnah fasting days: Ayyamul Bidh 13–15, Monday/Thursday are not events.
    expect(isAyyamulBidh(const HijriDate(1448, 5, 13)), isTrue);
    expect(isAyyamulBidh(const HijriDate(1448, 5, 16)), isFalse);
  });

  test('the correction is saved as hijri_adjust and clamped', () async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final n = c.read(hijriAdjustProvider.notifier);
    await n.ready;
    expect(c.read(hijriAdjustProvider), 0);
    await n.set(1);
    expect(
      (await SharedPreferences.getInstance()).getInt(HijriAdjustNotifier.key),
      1,
    );
    await n.set(5);
    expect(c.read(hijriAdjustProvider), 1);
    await n.set(-5);
    expect(c.read(hijriAdjustProvider), -1);
  });

  testWidgets('Beranda shows the offline Hijri date and opens the calendar', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({HijriAdjustNotifier.key: 1});
    await pumpHome(tester);
    expect(find.textContaining('14 Jumadil Awal 1448 H'), findsOneWidget);
    await tester.tap(find.textContaining('14 Jumadil Awal 1448 H'));
    await tester.pumpAndSettle();
    expect(find.byType(HijriCalendarScreen), findsOneWidget);
  });

  testWidgets('calendar: month grid, today, events and the correction', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          clockProvider.overrideWith(
            (ref) => Stream.value(DateTime(2026, 10, 25, 18, 2)),
          ),
        ],
        child: const MaterialApp(home: HijriCalendarScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Jumadil Awal 1448'), findsOneWidget);
    expect(
      find.textContaining('13 Okt'),
      findsOneWidget,
      reason: 'Gregorian range',
    );
    expect(find.byKey(const ValueKey('hijri-day-13')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('hijri-day-30')),
      findsOneWidget,
      reason: 'odd months have 30 days',
    );
    expect(find.text('Hari besar berikutnya'), findsOneWidget);
    expect(find.text('Isra Mikraj'), findsWidgets);
    expect(find.text('Awal Ramadhan'), findsWidgets);
    expect(find.textContaining('106 hari lagi'), findsOneWidget);

    await tester.tap(find.byTooltip('Bulan depan'));
    await tester.pumpAndSettle();
    expect(find.text('Jumadil Akhir 1448'), findsOneWidget);
    await tester.tap(find.byTooltip('Bulan lalu'));
    await tester.tap(find.byTooltip('Bulan lalu'));
    await tester.pumpAndSettle();
    expect(find.text('Rabiul Akhir 1448'), findsOneWidget);

    // Correction: +1 makes today the 14th; the setting is saved.
    await tester.scrollUntilVisible(find.text('+1 hari'), 200);
    await tester.pumpAndSettle();
    await tester.tap(find.text('+1 hari'));
    await tester.pumpAndSettle();
    expect(
      (await SharedPreferences.getInstance()).getInt(HijriAdjustNotifier.key),
      1,
    );
    await tester.drag(find.byType(ListView), const Offset(0, 1200));
    await tester.pumpAndSettle();
    expect(find.text('Hari ini 14 Jumadil Awal 1448 H'), findsOneWidget);
  });
}
