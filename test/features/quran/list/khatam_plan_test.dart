import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:muslimku/features/quran/application/khatam_plan_provider.dart';
import 'package:muslimku/features/quran/domain/khatam_plan.dart';
import 'package:muslimku/features/quran/presentation/khatam_plan_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/fake_quran_api.dart';
import 'pump_quran.dart';

void main() {
  setUpAll(() => initializeDateFormatting('id_ID', null));
  setUp(() => SharedPreferences.setMockInitialValues({}));

  final start = DateTime(2026, 10, 25);

  test('a plan spreads 30 juz over its days and tracks the pace', () {
    final plan = KhatamPlan(start: start, target: DateTime(2026, 11, 23));
    expect(plan.days, 30);
    expect(plan.juzPerDay, 1.0);
    expect(plan.label, 'Khatam 23 Nov 2026');
    // Day 1: nothing due yet beyond juz 1.
    var status = plan.status(doneJuz: 0, today: start);
    expect(status.dayNumber, 1);
    expect(status.daysLeft, 30);
    expect(status.expectedJuz, 1);
    expect(status.behind, 0);
    expect(status.todayTarget, 'Juz 1');
    expect(status.line, 'Hari ke-1 · target hari ini Juz 1');
    // Day 10 with 6 juz done: 3 juz behind, needs more per day.
    status = plan.status(doneJuz: 6, today: start.add(const Duration(days: 9)));
    expect(status.expectedJuz, 10);
    expect(status.behind, 3, reason: 'expected through juz 9 by yesterday');
    expect(status.daysLeft, 21);
    expect(status.perDayNeeded, closeTo(24 / 21, 0.001));
    expect(status.todayTarget, 'Juz 7–10');
    expect(status.line, 'Hari ke-10 · tertinggal 3 juz · 1,1 juz/hari');
    // Ahead of schedule.
    status = plan.status(
      doneJuz: 15,
      today: start.add(const Duration(days: 9)),
    );
    expect(status.behind, 0);
    expect(status.line, 'Hari ke-10 · 5 juz lebih cepat');
    // Done.
    status = plan.status(
      doneJuz: 30,
      today: start.add(const Duration(days: 5)),
    );
    expect(status.finished, isTrue);
    expect(status.line, 'Khatam! 30 juz selesai');
    // Past the target with juz left.
    status = plan.status(doneJuz: 20, today: DateTime(2026, 12, 1));
    expect(status.daysLeft, 0);
    expect(status.line, 'Lewat target · 10 juz tersisa');
  });

  test(
    'short plans: 1 juz a day is the slowest preset, ramadhan is 29 days',
    () {
      expect(KhatamPlan.presets.map((p) => p.$1), [
        '30 hari',
        'Ramadhan',
        '60 hari',
        '90 hari',
      ]);
      final ramadhan = KhatamPlan.preset(
        'Ramadhan',
        today: DateTime(2027, 2, 8),
      );
      expect(ramadhan.start, DateTime(2027, 2, 8));
      expect(ramadhan.target, DateTime(2027, 3, 8), reason: '29 days');
      expect(ramadhan.days, 29);
      final sixty = KhatamPlan.preset('60 hari', today: start);
      expect(sixty.juzPerDay, 0.5);
      expect(sixty.status(doneJuz: 0, today: start).todayTarget, 'Juz 1');
      expect(
        sixty
            .status(doneJuz: 0, today: start.add(const Duration(days: 1)))
            .todayTarget,
        'Juz 1',
        reason: 'half a juz per day: juz 1 is still due',
      );
      expect(
        sixty
            .status(doneJuz: 1, today: start.add(const Duration(days: 2)))
            .todayTarget,
        'Juz 2',
      );
      final roundTrip = KhatamPlan.fromJson(sixty.toJson());
      expect(roundTrip, sixty);
    },
  );

  test('the plan is saved as khatam_plan and can be cleared', () async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final n = c.read(khatamPlanProvider.notifier);
    await n.ready;
    expect(c.read(khatamPlanProvider), isNull);
    final plan = KhatamPlan.preset('30 hari', today: start);
    await n.set(plan);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(KhatamPlanNotifier.key), isNotNull);
    await n.clear();
    expect(c.read(khatamPlanProvider), isNull);
    expect(prefs.getString(KhatamPlanNotifier.key), isNull);
  });

  testWidgets('Juz tab: set a plan from the card, the card shows the pace', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'quran_khatam_juz': ['1', '2'],
    });
    await pumpQuran(tester, api: FakeQuranApi());
    await tester.tap(find.text('Juz'));
    await settle(tester);
    expect(find.text('Progres khatam'), findsOneWidget);
    expect(find.text('Buat rencana'), findsOneWidget);
    await tester.tap(find.text('Buat rencana'));
    await tester.pumpAndSettle();
    expect(find.byType(KhatamPlanSheet), findsOneWidget);
    expect(find.text('30 hari'), findsOneWidget);
    expect(find.text('Ramadhan'), findsOneWidget);
    await tester.tap(find.text('60 hari'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Simpan rencana'));
    await tester.pumpAndSettle();
    expect(find.byType(KhatamPlanSheet), findsNothing);
    expect(find.textContaining('Khatam '), findsOneWidget);
    expect(find.textContaining('Hari ke-1'), findsOneWidget);
    expect(find.text('Buat rencana'), findsNothing);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(KhatamPlanNotifier.key), contains('"days":60'));

    // Opening the card again offers to stop the plan.
    await tester.tap(find.textContaining('Khatam '));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hentikan rencana'));
    await tester.pumpAndSettle();
    expect(find.text('Buat rencana'), findsOneWidget);
    expect(prefs.getString(KhatamPlanNotifier.key), isNull);
  });
}
