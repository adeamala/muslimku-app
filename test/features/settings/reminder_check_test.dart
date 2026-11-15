import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:muslimku/core/network/api_service.dart';
import 'package:muslimku/core/storage/local_store.dart';
import 'package:muslimku/core/time/clock_provider.dart';
import 'package:muslimku/features/prayer/application/adzan_provider.dart';
import 'package:muslimku/features/prayer/data/reminder_gateway.dart';
import 'package:muslimku/features/prayer/domain/adzan_plan.dart';
import 'package:muslimku/features/settings/presentation/reminder_check_screen.dart';
import 'package:muslimku/features/settings/presentation/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_home_api.dart';
import 'settings_adzan_test.dart' show FakeGateway;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => initializeDateFormatting('id_ID', null));
  final now = DateTime(2026, 10, 25, 18, 2);
  setUp(() {
    SharedPreferences.setMockInitialValues({
      AdzanNotifier.enabledKey: true,
      AdzanNotifier.soundKey: 'bedug',
    });
  });

  Future<FakeGateway> pump(WidgetTester tester, FakeGateway gateway) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiServiceProvider.overrideWithValue(FakeHomeApi()),
          localStoreProvider.overrideWithValue(MemoryLocalStore()),
          reminderGatewayProvider.overrideWithValue(gateway),
          clockProvider.overrideWith((ref) => Stream.value(now)),
          nowProvider.overrideWithValue(() => now),
        ],
        child: const MaterialApp(home: ReminderCheckScreen()),
      ),
    );
    await tester.pumpAndSettle();
    return gateway;
  }

  testWidgets('all green: every check passes and the next reminder shows', (
    tester,
  ) async {
    final g = await pump(tester, FakeGateway());
    expect(find.text('Cek pengingat'), findsOneWidget);
    expect(find.text('Notifikasi'), findsOneWidget);
    expect(find.text('Alarm tepat waktu'), findsOneWidget);
    expect(find.text('Penghemat baterai'), findsOneWidget);
    expect(find.text('Pengingat terpasang'), findsOneWidget);
    expect(find.text('Diizinkan'), findsNWidgets(2));
    expect(find.text('Tidak dibatasi'), findsOneWidget);
    // 18:02 on 25 Oct: Isya 18:40 is next (early reminder 18:30 first).
    expect(
      find.textContaining('Berikutnya: 10 menit lagi Isya · 18:30'),
      findsOneWidget,
    );
    expect(find.textContaining('pengingat 14 hari ke depan'), findsOneWidget);
    expect(find.text('Semua siap'), findsOneWidget);
    expect(find.text('Perbaiki'), findsNothing);

    await tester.tap(find.text('Coba bunyikan sekarang'));
    await tester.pumpAndSettle();
    expect(g.tests, [AdzanSound.bedug]);
    expect(find.textContaining('Notifikasi percobaan dikirim'), findsOneWidget);
  });

  testWidgets('each problem has a fix', (tester) async {
    final g = await pump(
      tester,
      FakeGateway(allow: false, exact: false, battery: false),
    );
    expect(find.text('Ditolak'), findsOneWidget);
    expect(find.text('Belum diizinkan'), findsOneWidget);
    expect(find.text('Dibatasi'), findsOneWidget);
    expect(find.text('Perbaiki'), findsNWidgets(3));
    expect(find.text('3 hal perlu dicek'), findsOneWidget);

    // Notifications: asks again, and when still refused opens the settings.
    await tester.tap(find.text('Perbaiki').at(0));
    await tester.pumpAndSettle();
    expect(g.permissionRequests, 1);
    expect(g.settingsOpened, 1);
    g.allow = true;

    await tester.tap(find.text('Perbaiki').at(1));
    await tester.pumpAndSettle();
    expect(g.exact, isTrue);

    await tester.tap(find.text('Perbaiki').at(0));
    await tester.pumpAndSettle();
    expect(g.batterySettingsOpened, 1);
    g.battery = true;

    // "Cek lagi" re-reads everything.
    await tester.scrollUntilVisible(find.text('Cek lagi'), 200);
    await tester.tap(find.text('Cek lagi'));
    await tester.pumpAndSettle();
    expect(find.text('Perbaiki', skipOffstage: false), findsNothing);
    expect(find.text('Semua siap', skipOffstage: false), findsOneWidget);
  });

  testWidgets('without reminders on, says so and offers Pengaturan', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await pump(tester, FakeGateway());
    expect(find.text('Pengingat adzan mati'), findsOneWidget);
    expect(find.text('Coba bunyikan sekarang'), findsNothing);
  });

  testWidgets('Pengaturan links to it', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiServiceProvider.overrideWithValue(FakeHomeApi()),
          localStoreProvider.overrideWithValue(MemoryLocalStore()),
          reminderGatewayProvider.overrideWithValue(FakeGateway()),
          clockProvider.overrideWith((ref) => Stream.value(now)),
          nowProvider.overrideWithValue(() => now),
        ],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Cek pengingat'), 200);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cek pengingat'));
    await tester.pumpAndSettle();
    expect(find.byType(ReminderCheckScreen), findsOneWidget);
  });
}
