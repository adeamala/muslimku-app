import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:muslimku/core/network/api_service.dart';
import 'package:muslimku/core/storage/local_store.dart';
import 'package:muslimku/features/prayer/data/reminder_gateway.dart';
import 'package:muslimku/features/settings/presentation/privacy_policy_screen.dart';
import 'package:muslimku/features/settings/presentation/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_home_api.dart';

Widget _app(Widget home, {double scale = 1}) => ProviderScope(
  overrides: [
    apiServiceProvider.overrideWithValue(FakeHomeApi()),
    localStoreProvider.overrideWithValue(MemoryLocalStore()),
    reminderGatewayProvider.overrideWithValue(const NoReminderGateway()),
  ],
  child: MaterialApp(
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(scale), disableAnimations: true),
      child: child!,
    ),
    home: home,
  ),
);

void _phone(WidgetTester tester, {double width = 390, double height = 844}) {
  tester.view.physicalSize = Size(width * 3, height * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

void main() {
  setUpAll(() => initializeDateFormatting('id_ID', null));
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Pengaturan > Tentang opens the privacy policy and back', (
    tester,
  ) async {
    _phone(tester);
    await tester.pumpWidget(_app(const SettingsScreen()));
    await tester.pumpAndSettle();
    final row = find.text('Kebijakan privasi');
    await tester.scrollUntilVisible(row, 200);
    await tester.pumpAndSettle();
    await tester.tap(row);
    await tester.pumpAndSettle();

    expect(find.byType(PrivacyPolicyScreen), findsOneWidget);
    expect(find.text('Terakhir diperbarui 28 Oktober 2026'), findsOneWidget);

    await tester.tap(find.byTooltip('Kembali'));
    await tester.pumpAndSettle();
    expect(find.byType(PrivacyPolicyScreen), findsNothing);
    // Back on Pengaturan, still scrolled down to Tentang.
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.text('Kebijakan privasi'), findsOneWidget);
  });

  testWidgets('the policy covers what Play asks for, readable at 130%', (
    tester,
  ) async {
    _phone(tester, width: 360, height: 740);
    await tester.pumpWidget(_app(const PrivacyPolicyScreen(), scale: 1.3));
    await tester.pumpAndSettle();

    // In reading order, so scrolling only goes down.
    for (final text in [
      'tidak meminta akun',
      'tidak menampilkan iklan',
      'Koordinatnya tidak disimpan dan tidak dikirim',
      'api.myquran.com',
      'HTTPS',
      'alarm tepat waktu',
      'PT Sahabat Sejahtera Jayati',
      'developer.cvai@gmail.com',
    ]) {
      final finder = find.textContaining(text);
      await tester.scrollUntilVisible(finder, 300);
      expect(finder, findsWidgets, reason: text);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('section titles are headings for TalkBack', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_app(const PrivacyPolicyScreen()));
    await tester.pumpAndSettle();
    final title = find.text('Lokasi');
    await tester.scrollUntilVisible(title, 200);
    expect(tester.getSemantics(title), containsSemantics(isHeader: true));
  });
}
