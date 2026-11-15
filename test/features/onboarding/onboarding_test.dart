import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:muslimku/core/network/api_service.dart';
import 'package:muslimku/core/storage/local_store.dart';
import 'package:muslimku/features/location/application/location_provider.dart';
import 'package:muslimku/features/onboarding/presentation/onboarding_screen.dart';
import 'package:muslimku/features/prayer/application/adzan_provider.dart';
import 'package:muslimku/features/prayer/data/reminder_gateway.dart';
import 'package:muslimku/features/prayer/domain/adzan_plan.dart';
import 'package:muslimku/features/qibla/application/qibla_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_home_api.dart';
import '../settings/settings_adzan_test.dart' show FakeGateway, FakeLocation;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => initializeDateFormatting('id_ID', null));
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('onboarding is needed only on a fresh install', () async {
    expect(await needsOnboarding(), isTrue);
    SharedPreferences.setMockInitialValues({'selectedCityId': '1301'});
    expect(
      await needsOnboarding(),
      isFalse,
      reason: 'a 1.0.1 user with a city never sees it',
    );
    SharedPreferences.setMockInitialValues({onboardingDoneKey: true});
    expect(await needsOnboarding(), isFalse);
  });

  Future<(FakeGateway, List<String>)> pump(
    WidgetTester tester, {
    QiblaLocation? located,
  }) async {
    final gateway = FakeGateway();
    final done = <String>[];
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiServiceProvider.overrideWithValue(FakeHomeApi()),
          localStoreProvider.overrideWithValue(MemoryLocalStore()),
          reminderGatewayProvider.overrideWithValue(gateway),
          if (located != null)
            qiblaLocationSourceProvider.overrideWithValue(
              FakeLocation(located),
            ),
        ],
        child: MaterialApp(
          home: OnboardingScreen(onDone: () => done.add('done')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return (gateway, done);
  }

  testWidgets('three steps: city, reminders, sound, then done', (tester) async {
    final (gateway, done) = await pump(tester);
    // Step 1: city, defaulting to Kota Kediri.
    expect(find.text('Kota kamu'), findsOneWidget);
    expect(find.text('Kota Kediri'), findsOneWidget);
    expect(find.text('Langkah 1 dari 3'), findsOneWidget);
    expect(find.text('Pakai lokasi saya'), findsOneWidget);
    expect(find.text('Pilih kota'), findsOneWidget);
    await tester.tap(find.text('Lanjut'));
    await tester.pumpAndSettle();

    // Step 2: reminders off by default; switching on asks permission.
    expect(find.text('Pengingat adzan'), findsOneWidget);
    expect(find.text('Langkah 2 dari 3'), findsOneWidget);
    await tester.tap(find.text('Nyalakan pengingat'));
    await tester.pumpAndSettle();
    expect(gateway.permissionRequests, 1);
    expect(find.text('Pengingat aktif'), findsOneWidget);
    await tester.tap(find.text('Lanjut'));
    await tester.pumpAndSettle();

    // Step 3: sound, same rows as the settings sheet.
    expect(find.text('Suara pengingat'), findsOneWidget);
    expect(find.text('Langkah 3 dari 3'), findsOneWidget);
    expect(find.text('Bedug'), findsOneWidget);
    await tester.tap(find.text('Bedug'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mulai'));
    await tester.pumpAndSettle();
    expect(done, ['done']);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(onboardingDoneKey), isTrue);
    expect(prefs.getBool(AdzanNotifier.enabledKey), isTrue);
    expect(prefs.getString(AdzanNotifier.soundKey), 'bedug');
    expect(
      gateway.scheduled.map((r) => r.sound).toSet(),
      contains(AdzanSound.bedug),
    );
  });

  testWidgets('"Pakai lokasi saya" picks the nearest city', (tester) async {
    // Jakarta: the nearest bundled city is KOTA JAKARTA (1301).
    final (_, _) = await pump(
      tester,
      located: const QiblaLocation(
        QiblaLocationStatus.ok,
        latitude: -6.2,
        longitude: 106.82,
      ),
    );
    await tester.tap(find.text('Pakai lokasi saya'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Jakarta'), findsWidgets);
    expect(find.text('Kota Kediri'), findsNothing);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('selectedCityId'), isNotNull);
  });

  testWidgets('"Nanti saja" skips without touching the settings', (
    tester,
  ) async {
    final (gateway, done) = await pump(tester);
    await tester.tap(find.text('Lanjut'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nanti saja'));
    await tester.pumpAndSettle();
    expect(gateway.permissionRequests, 0);
    // The sound step is skipped when reminders stay off.
    expect(done, ['done']);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(onboardingDoneKey), isTrue);
    expect(prefs.getBool(AdzanNotifier.enabledKey), isNot(true));
  });

  test('the Beranda location falls back to the default city', () {
    expect(LocationState().cityName, 'KOTA KEDIRI');
  });
}
