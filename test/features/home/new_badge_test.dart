import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:muslimku/features/calendar/presentation/hijri_calendar_screen.dart';
import 'package:muslimku/features/home/presentation/widgets/ibadah_grid.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/pump_home.dart';

void main() {
  setUpAll(() => initializeDateFormatting('id_ID', null));
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('the NEW badge disappears once the feature was opened', (
    tester,
  ) async {
    await pumpHome(tester);
    // 1.4.0 badges Kalender, Catatan and Jadwal; Kiblat and Tasbih no longer.
    expect(find.text('BARU'), findsNWidgets(3));

    final kalender = find.descendant(
      of: find.byType(IbadahGrid),
      matching: find.text('Kalender'),
    );
    await tester.ensureVisible(kalender);
    await tester.tap(kalender);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(HijriCalendarScreen), findsOneWidget);

    Navigator.of(tester.element(find.byType(HijriCalendarScreen))).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('BARU'), findsNWidgets(2));

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('seen_feature_kalender'), isTrue);
  });

  testWidgets('a badge seen in an earlier session stays hidden', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'seen_feature_catatan': true});
    await pumpHome(tester);
    expect(find.text('BARU'), findsNWidgets(2));
  });
}
