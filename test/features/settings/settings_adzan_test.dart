import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:muslimku/core/network/api_service.dart';
import 'package:muslimku/core/storage/local_store.dart';
import 'package:muslimku/features/location/application/device_city_provider.dart';
import 'package:muslimku/features/location/application/location_provider.dart';
import 'package:muslimku/features/location/domain/nearest_city.dart';
import 'package:muslimku/features/prayer/application/adzan_provider.dart';
import 'package:muslimku/features/prayer/application/prayer_time_provider.dart';
import 'package:muslimku/features/prayer/data/prayer_schedule_repository.dart';
import 'package:muslimku/features/prayer/data/reminder_gateway.dart';
import 'package:muslimku/features/prayer/domain/adzan_plan.dart';
import 'package:muslimku/features/prayer/domain/prayer_time_model.dart';
import 'package:muslimku/features/qibla/application/qibla_provider.dart';
import 'package:muslimku/features/settings/presentation/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_home_api.dart';

class FakeGateway implements ReminderGateway {
  FakeGateway({this.allow = true, this.exact = true, this.battery = true});

  bool allow;
  bool exact;
  bool battery;
  int permissionRequests = 0;
  int settingsOpened = 0;
  int batterySettingsOpened = 0;
  int cancels = 0;
  List<AdzanReminder> scheduled = [];
  final List<AdzanSound> tests = [];
  bool? lastExact;

  @override
  Future<void> openNotificationSettings() async => settingsOpened++;

  @override
  Future<bool> batteryUnrestricted() async => battery;

  @override
  Future<void> openBatterySettings() async => batterySettingsOpened++;

  @override
  Future<void> showNow(AdzanReminder reminder) async =>
      tests.add(reminder.sound);

  @override
  Future<bool> notificationsAllowed({bool request = false}) async {
    if (request) permissionRequests++;
    return allow;
  }

  @override
  Future<bool> exactAlarmsAllowed() async => exact;

  @override
  Future<void> requestExactAlarms() async => exact = true;

  @override
  Future<void> replaceAll(
    List<AdzanReminder> reminders, {
    required bool exact,
  }) async {
    scheduled = reminders;
    lastExact = exact;
  }

  @override
  Future<void> cancelAll() async {
    cancels++;
    scheduled = [];
  }
}

class FakeLocation implements QiblaLocationSource {
  FakeLocation(this.result);

  QiblaLocation result;

  @override
  Future<QiblaLocation> locate({bool request = true}) async => result;

  @override
  Future<void> openAppSettings() async {}

  @override
  Future<void> openLocationSettings() async {}
}

PrayerSchedule day(String date) => PrayerSchedule.fromJson({
  ...FakeHomeApi.jadwal.jadwal.toJson(),
  'date': date,
});

/// Today's times from MyQuran, one minute off the saved month (03:49).
final _freshDay = <String, dynamic>{
  ...FakeHomeApi.jadwal.toJson(),
  'jadwal': {...FakeHomeApi.jadwal.jadwal.toJson(), 'subuh': '03:50'},
};

/// Holds the daily request until the test answers it (a slow network).
class _SlowPrayerApi extends FakeHomeApi {
  final answer = Completer<Map<String, dynamic>?>();
  int requests = 0;

  @override
  Future<Map<String, dynamic>?> getPrayerTimes(String cityId, String date) {
    requests++;
    return answer.future;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => initializeDateFormatting('id_ID', null));
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('AdzanPlan', () {
    final days = [day('2026-10-25'), day('2026-10-26')];

    test('plans the remaining prayers and early reminders in order', () {
      final now = DateTime(2026, 10, 25, 14, 25); // 4 min before Ashar
      final plan = AdzanPlan.build(
        days: days,
        settings: const AdzanSettings(enabled: true),
        now: now,
        city: 'Kota Kediri',
      );
      expect(plan.first.title, 'Waktunya Ashar');
      expect(plan.first.at, DateTime(2026, 10, 25, 14, 29));
      expect(plan[1].title, '10 menit lagi Maghrib');
      expect(plan[1].at, DateTime(2026, 10, 25, 17, 19));
      expect(plan[1].body, 'Maghrib pukul 17:29 · Kota Kediri');
      // Today: Ashar (early one already passed), Maghrib x2, Isya x2; tomorrow 10.
      expect(plan, hasLength(15));
      expect(plan.map((r) => r.id).toSet(), hasLength(15));
      expect(
        AdzanPlan.idFor(DateTime(2026, 10, 25), AdzanPrayer.isya, early: true),
        202610259,
      );
    });

    test('respects the chosen prayers and the switch', () {
      final now = DateTime(2026, 10, 25, 0, 0);
      final plan = AdzanPlan.build(
        days: days,
        settings: const AdzanSettings(
          enabled: true,
          prayers: {AdzanPrayer.subuh},
          remindBefore: false,
        ),
        now: now,
        city: 'Kota Kediri',
      );
      expect(plan.map((r) => r.title), ['Waktunya Subuh', 'Waktunya Subuh']);
      expect(
        AdzanPlan.build(
          days: days,
          settings: const AdzanSettings(),
          now: now,
          city: 'x',
        ),
        isEmpty,
      );
    });

    String iso(DateTime d) => d.toIso8601String().substring(0, 10);
    List<PrayerSchedule> daysFrom(DateTime first, int count) => [
      for (var i = 0; i < count; i++) day(iso(first.add(Duration(days: i)))),
    ];

    test('ends with one notice to open the app a day before it runs out', () {
      final now = DateTime(2026, 10, 25, 14, 25);
      final plan = AdzanPlan.build(
        days: daysFrom(DateTime(2026, 10, 25), 16),
        settings: const AdzanSettings(enabled: true),
        now: now,
        city: 'Kota Kediri',
      );
      // 14 days of each of the 10 daily reminders, as before.
      expect(plan.where((r) => !r.renewal), hasLength(140));
      final notice = plan.singleWhere((r) => r.renewal);
      // The last reminder is "10 menit lagi Ashar" on 8 Nov at 14:19.
      expect(notice.at, DateTime(2026, 11, 7, 14, 19));
      expect(notice.id, AdzanPlan.renewalId);
      expect(notice.prayer, isNull);
      expect(notice.title, 'Pengingat adzan hampir habis');
      expect(
        notice.body,
        'Pengingat terpasang sampai 8 Nov. '
        'Buka Muslimku sebentar agar diperpanjang.',
      );
      expect(plan.map((r) => r.id).toSet(), hasLength(plan.length));
      expect(plan.map((r) => r.at).toList(), [
        for (final r in [...plan]..sort((a, b) => a.at.compareTo(b.at))) r.at,
      ]);
    });

    test('keeps the notice in waking hours', () {
      final plan = AdzanPlan.build(
        days: daysFrom(DateTime(2026, 10, 25), 16),
        settings: const AdzanSettings(
          enabled: true,
          prayers: {AdzanPrayer.subuh},
          remindBefore: false,
        ),
        now: DateTime(2026, 10, 25, 0, 0),
        city: 'Kota Kediri',
      );
      // Last Subuh is 7 Nov 03:49; a day earlier at 03:49 moves to 07:00.
      expect(plan.singleWhere((r) => r.renewal).at, DateTime(2026, 11, 6, 7));
    });

    test('a plan of a day or two needs no notice', () {
      final plan = AdzanPlan.build(
        days: days,
        settings: const AdzanSettings(enabled: true),
        now: DateTime(2026, 10, 25, 14, 25),
        city: 'Kota Kediri',
      );
      expect(plan.where((r) => r.renewal), isEmpty);
    });
  });

  test('the bundled city table finds the nearest MyQuran city', () async {
    final cities = parseCityTable(
      await rootBundle.loadString('assets/data/kota.json'),
    );
    expect(cities.length, greaterThan(500));
    expect(nearestCity(-7.8166, 112.0112, cities)!.name, 'KOTA KEDIRI');
    expect(nearestCity(-6.1754, 106.8272, cities)!.id, '1301');
    expect(distanceKm(-6.2, 106.8, -7.8, 112.0), closeTo(600, 40));
  });

  ProviderContainer container({
    FakeGateway? gateway,
    FakeHomeApi? api,
    QiblaLocationSource? location,
  }) {
    final c = ProviderContainer(
      overrides: [
        apiServiceProvider.overrideWithValue(api ?? FakeHomeApi()),
        localStoreProvider.overrideWithValue(MemoryLocalStore()),
        reminderGatewayProvider.overrideWithValue(gateway ?? FakeGateway()),
        if (location != null)
          qiblaLocationSourceProvider.overrideWithValue(location),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  test(
    'switching reminders on asks permission and schedules 14 days',
    () async {
      final gateway = FakeGateway();
      final c = container(gateway: gateway);
      final adzan = c.read(adzanProvider.notifier);
      await adzan.ready;
      await adzan.setEnabled(true);
      expect(gateway.permissionRequests, 1);
      expect(c.read(adzanProvider).settings.enabled, isTrue);
      final prayers = gateway.scheduled.where((r) => !r.renewal);
      expect(prayers.length, greaterThan(100));
      expect(prayers.length, lessThanOrEqualTo(14 * 10));
      expect(gateway.scheduled.where((r) => r.renewal), hasLength(1));
      expect(gateway.lastExact, isTrue);
      // Pengaturan counts the prayer reminders, not the renewal notice.
      expect(c.read(adzanProvider).scheduled, prayers.length);

      final before = gateway.scheduled.length;
      await adzan.togglePrayer(AdzanPrayer.dzuhur);
      expect(gateway.scheduled.length, lessThan(before));
      expect(
        gateway.scheduled.any((r) => r.prayer == AdzanPrayer.dzuhur),
        isFalse,
      );

      await adzan.setEnabled(false);
      expect(gateway.cancels, 1);
      expect(c.read(adzanProvider).scheduled, 0);

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getStringList(AdzanNotifier.prayersKey),
        isNot(contains('dzuhur')),
      );
    },
  );

  test('a refused permission keeps reminders off', () async {
    final gateway = FakeGateway(allow: false);
    final c = container(gateway: gateway);
    await c.read(adzanProvider.notifier).setEnabled(true);
    expect(c.read(adzanProvider).settings.enabled, isFalse);
    expect(c.read(adzanProvider).notificationsDenied, isTrue);
    expect(gateway.scheduled, isEmpty);
  });

  test(
    'without any saved schedule offline, explains instead of failing',
    () async {
      final c = container(api: FakeHomeApi(failPrayerTimes: true));
      await c.read(adzanProvider.notifier).setEnabled(true);
      expect(c.read(adzanProvider).message, contains('belum tersimpan'));
    },
  );

  test('Beranda falls back to the saved month when offline', () async {
    final api = FakeHomeApi();
    final c = container(api: api);
    final now = DateTime.now();
    await c
        .read(prayerScheduleRepositoryProvider)
        .month('1632', now.year, now.month);
    api.failPrayerTimes = true;
    await c.read(prayerTimeProvider.notifier).loadPrayerTimes(cityId: '1632');
    final state = c.read(prayerTimeProvider);
    expect(state.error, isNull);
    expect(state.fromSaved, isTrue);
    expect(state.prayerTime!.jadwal.subuh, '03:49');
  });

  test('Beranda shows the saved month at once, then the fresh day', () async {
    final api = _SlowPrayerApi();
    final c = container(api: api);
    final now = DateTime.now();
    await c
        .read(prayerScheduleRepositoryProvider)
        .month('1632', now.year, now.month);

    final load = c
        .read(prayerTimeProvider.notifier)
        .loadPrayerTimes(cityId: '1632');
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    // The request is still on its way, yet the stage already has times.
    expect(api.requests, 1);
    var state = c.read(prayerTimeProvider);
    expect(state.prayerTime?.jadwal.subuh, '03:49');
    expect(state.isLoading, isFalse);
    expect(state.error, isNull);

    api.answer.complete(_freshDay);
    await load;
    state = c.read(prayerTimeProvider);
    expect(state.fromSaved, isFalse);
    expect(state.prayerTime?.jadwal.subuh, '03:50');
  });

  test('"Pakai lokasi saya" picks the nearest city on the phone', () async {
    final c = container(
      location: FakeLocation(
        const QiblaLocation(
          QiblaLocationStatus.ok,
          latitude: -7.82,
          longitude: 112.01,
        ),
      ),
    );
    final message = await c
        .read(deviceCityProvider.notifier)
        .useDeviceLocation();
    expect(message, 'Kota diatur ke Kota Kediri');
    await Future<void>.delayed(Duration.zero);
    expect(c.read(locationProvider).activeCityId, '1632');
    expect(c.read(deviceCityProvider).deviceCityId, '1632');

    final denied = container(
      location: FakeLocation(const QiblaLocation(QiblaLocationStatus.denied)),
    );
    expect(
      await denied.read(deviceCityProvider.notifier).useDeviceLocation(),
      'Izin lokasi ditolak.',
    );
  });

  testWidgets('Pengaturan shows every section and the adzan options', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiServiceProvider.overrideWithValue(FakeHomeApi()),
          localStoreProvider.overrideWithValue(MemoryLocalStore()),
          reminderGatewayProvider.overrideWithValue(FakeGateway()),
        ],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Pengaturan'), findsOneWidget);
    for (final label in [
      'LOKASI & JADWAL',
      'PENGINGAT ADZAN',
      'TAMPILAN',
      'DATA OFFLINE',
    ]) {
      await tester.scrollUntilVisible(find.text(label), 200);
      expect(find.text(label), findsOneWidget);
    }
    await tester.scrollUntilVisible(find.text('Pengingat adzan'), -200);
    // Centre the row: ensureVisible's top alignment can leave it under the
    // header, where a tap does not land.
    await Scrollable.ensureVisible(
      tester.element(find.text('Pengingat adzan').last),
      alignment: 0.5,
    );
    await tester.pumpAndSettle();
    expect(find.text('Ingatkan 10 menit sebelumnya'), findsNothing);
    // The master toggle is the Switch of the "Pengingat adzan" row (not the
    // first Switch built, which depends on the scroll position).
    final row = find.ancestor(
      of: find.text('Pengingat adzan').last,
      matching: find.byWidgetPredicate(
        (w) => w.runtimeType.toString() == '_Row',
      ),
    );
    await tester.tap(find.descendant(of: row, matching: find.byType(Switch)));
    await tester.pumpAndSettle();
    expect(find.text('Ingatkan 10 menit sebelumnya'), findsOneWidget);
    expect(find.textContaining('pengingat 14 hari ke depan'), findsOneWidget);
  });
}
