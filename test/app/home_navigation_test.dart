import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:muslimku/app/shell/bottom_navigation_bar.dart';
import 'package:muslimku/app/shell/home_screen.dart';
import 'package:muslimku/features/doa/presentation/doa_screen.dart';
import 'package:muslimku/features/home/presentation/home_tab.dart';
import 'package:muslimku/features/quran/presentation/quran_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/pump_home.dart';

Future<void> _openTab(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(
      of: find.byType(CustomBottomNavigationBar),
      matching: find.text(label),
    ),
  );
  await settle(tester);
}

Finder _visible(Type type) => find.byType(type, skipOffstage: true);

void main() {
  setUpAll(() => initializeDateFormatting('id_ID', null));
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Back on another tab returns to Beranda instead of closing', (
    tester,
  ) async {
    await pumpHome(tester);
    await _openTab(tester, 'Doa');
    expect(_visible(DoaScreen), findsOneWidget);

    final handled = await tester.binding.handlePopRoute();
    await settle(tester);

    expect(handled, isTrue, reason: 'the app must consume Back');
    expect(_visible(HomeTab), findsOneWidget);
    expect(_visible(DoaScreen), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('switching tabs keeps them alive instead of reloading', (
    tester,
  ) async {
    final api = await pumpHome(tester);
    await _openTab(tester, "Al-Qur'an");
    expect(_visible(QuranScreen), findsOneWidget);
    expect(api.suratListCalls, 1);

    await _openTab(tester, 'Doa');
    await _openTab(tester, "Al-Qur'an");
    expect(api.suratListCalls, 1, reason: 'the surat list was fetched again');
  });
}
