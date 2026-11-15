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
import 'package:muslimku/features/prayer/domain/prayer_time_model.dart';
import 'package:muslimku/features/settings/presentation/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_home_api.dart';
import 'settings_adzan_test.dart' show FakeGateway;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => initializeDateFormatting('id_ID', null));
  setUp(() => SharedPreferences.setMockInitialValues({}));

  PrayerSchedule day(String date) => PrayerSchedule.fromJson({
    ...FakeHomeApi.jadwal.jadwal.toJson(),
    'date': date,
  });
  // Sunday 25 Oct 2026 18:02; maghrib 17:29, subuh 03:49, isya 18:40.
  final now = DateTime(2026, 10, 25, 18, 2);
  final days = [
    for (var d = 25; d <= 31; d++) day('2026-10-$d'),
    for (var d = 1; d <= 9; d++) day('2026-11-0$d'),
  ];
  const all = AdzanSettings(enabled: true, extras: {...ExtraReminder.values});

  List<AdzanReminder> plan(AdzanSettings s, {String? Function(DateTime)? h}) =>
      AdzanPlan.build(
        days: days,
        settings: s,
        now: now,
        city: 'Kediri',
        hadithFor: h,
      );

  test('ExtraReminder labels, ids and prefs names', () {
    expect(ExtraReminder.values.map((e) => e.name), [
      'tahajjud',
      'kahfi',
      'puasaSunnah',
      'harian',
    ]);
    expect(ExtraReminder.tahajjud.label, 'Tahajjud');
    expect(ExtraReminder.kahfi.label, 'Al-Kahfi hari Jumat');
    expect(ExtraReminder.puasaSunnah.label, 'Puasa Senin–Kamis');
    expect(ExtraReminder.harian.label, 'Ayat & hadits hari ini');
    final d = DateTime(2026, 10, 26);
    final ids = {
      for (final e in ExtraReminder.values) AdzanPlan.extraIdFor(e, d),
      AdzanPlan.sahurIdFor(d),
      AdzanPlan.idFor(d, AdzanPrayer.isya, early: true),
    };
    expect(ids, hasLength(6), reason: 'no id collisions');
    expect(ids.every((i) => i > 0 && i < 2147483647), isTrue);
  });

  test('tahajjud comes at the last third of the night', () {
    final r = plan(
      const AdzanSettings(enabled: true, extras: {ExtraReminder.tahajjud}),
    ).where((r) => r.extra == ExtraReminder.tahajjud).toList();
    // Night 17:29 -> 03:49 (+1 day) = 620 min; last third starts +413 min = 00:22.
    expect(r.first.at, DateTime(2026, 10, 26, 0, 22));
    expect(r.first.title, 'Waktu tahajjud');
    expect(r.first.body, contains('Sepertiga malam terakhir'));
    expect(r.first.body, contains('Subuh 03:49'));
    expect(
      r.first.sound,
      AdzanSound.bawaan,
      reason: 'never the adzan at night',
    );
    expect(
      r.first.id,
      AdzanPlan.extraIdFor(ExtraReminder.tahajjud, DateTime(2026, 10, 25)),
    );
    expect(r.length, 14, reason: 'one per night within the horizon');
  });

  test(
    'Al-Kahfi on Fridays at 06:00, fasting on Sunday and Wednesday evenings',
    () {
      final kahfi = plan(
        const AdzanSettings(enabled: true, extras: {ExtraReminder.kahfi}),
      ).where((r) => r.extra == ExtraReminder.kahfi).map((r) => r.at).toList();
      expect(kahfi, [DateTime(2026, 10, 30, 6), DateTime(2026, 11, 6, 6)]);

      final puasa = plan(
        const AdzanSettings(enabled: true, extras: {ExtraReminder.puasaSunnah}),
      ).where((r) => r.extra == ExtraReminder.puasaSunnah).toList();
      expect(puasa.map((r) => r.at).toList(), [
        DateTime(2026, 10, 25, 20), // Sunday evening: tomorrow Monday
        DateTime(2026, 10, 28, 20), // Wednesday evening: tomorrow Thursday
        DateTime(2026, 11, 1, 20),
        DateTime(2026, 11, 4, 20),
      ]);
      expect(puasa.first.title, 'Besok Senin, puasa sunnah?');
      expect(puasa.first.body, contains('sahur'));
    },
  );

  test('the daily reminder carries the hadith of the day', () {
    final r = plan(
      const AdzanSettings(enabled: true, extras: {ExtraReminder.harian}),
      h: (d) => d.day == 26 ? 'Hadits hari ini: Niat (Arbain No. 1)' : null,
    ).where((r) => r.extra == ExtraReminder.harian).toList();
    expect(
      r.first.at,
      DateTime(2026, 10, 26, 7),
      reason: '07:00 today is past',
    );
    expect(r.first.title, 'Ayat & hadits hari ini');
    expect(r.first.body, 'Hadits hari ini: Niat (Arbain No. 1)');
    expect(r[1].body, contains('Buka Muslimku'));
    expect(r.length, 14);
  });

  test('extras need the reminders switch on, and never the early channel', () {
    expect(
      plan(const AdzanSettings(extras: {...ExtraReminder.values})),
      isEmpty,
    );
    final r = plan(all);
    expect(r.where((x) => x.extra != null && x.early), isEmpty);
    expect(r.where((x) => x.extra != null && x.renewal), isEmpty);
    // Sorted by time, renewal still included.
    expect(r.map((x) => x.at).toList(), List.of(r.map((x) => x.at))..sort());
    expect(r.where((x) => x.renewal), hasLength(1));
    expect(r.length, lessThan(400), reason: 'Android allows 500 alarms');
  });

  test('channel ids: extras share one channel with the system sound', () {
    expect(LocalReminderGateway.extrasChannel.channelId, 'adzan_lainnya');
    expect(LocalReminderGateway.extrasChannel.playSound, isTrue);
    expect(LocalReminderGateway.extrasChannel.sound, isNull);
  });

  test('the settings are saved and re-planned', () async {
    final gateway = FakeGateway();
    final c = ProviderContainer(
      overrides: [
        apiServiceProvider.overrideWithValue(FakeHomeApi()),
        localStoreProvider.overrideWithValue(MemoryLocalStore()),
        reminderGatewayProvider.overrideWithValue(gateway),
        nowProvider.overrideWithValue(() => now),
      ],
    );
    addTearDown(c.dispose);
    c.listen(adzanProvider, (_, _) {});
    final n = c.read(adzanProvider.notifier);
    await n.ready;
    await n.setEnabled(true);
    expect(gateway.scheduled.where((r) => r.extra != null), isEmpty);
    await n.toggleExtra(ExtraReminder.tahajjud);
    await n.toggleExtra(ExtraReminder.kahfi);
    expect(
      gateway.scheduled.where((r) => r.extra == ExtraReminder.tahajjud),
      isNotEmpty,
    );
    expect(
      gateway.scheduled.where((r) => r.extra == ExtraReminder.kahfi),
      isNotEmpty,
    );
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList(AdzanNotifier.extrasKey), ['tahajjud', 'kahfi']);
    await n.toggleExtra(ExtraReminder.kahfi);
    expect(
      gateway.scheduled.where((r) => r.extra == ExtraReminder.kahfi),
      isEmpty,
    );
  });

  testWidgets('Pengaturan > Pengingat lainnya sheet', (tester) async {
    SharedPreferences.setMockInitialValues({AdzanNotifier.enabledKey: true});
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiServiceProvider.overrideWithValue(FakeHomeApi()),
          localStoreProvider.overrideWithValue(MemoryLocalStore()),
          reminderGatewayProvider.overrideWithValue(FakeGateway()),
          nowProvider.overrideWithValue(() => now),
        ],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Pengingat lainnya'), 200);
    await tester.pumpAndSettle();
    expect(find.text('Tidak ada'), findsOneWidget);
    await tester.tap(find.text('Pengingat lainnya'));
    await tester.pumpAndSettle();
    expect(find.text('Tahajjud'), findsOneWidget);
    expect(find.text('Sepertiga malam terakhir'), findsOneWidget);
    expect(find.text('Al-Kahfi hari Jumat'), findsOneWidget);
    final tahajjudRow = find.ancestor(
      of: find.text('Tahajjud'),
      matching: find.byType(MergeSemantics),
    );
    await tester.tap(
      find.descendant(of: tahajjudRow, matching: find.byType(Switch)),
    );
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(195, 40));
    await tester.pumpAndSettle();
    expect(
      find.text('Tahajjud'),
      findsOneWidget,
      reason: 'the row subtitle names it',
    );
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList(AdzanNotifier.extrasKey), ['tahajjud']);
  });
}
