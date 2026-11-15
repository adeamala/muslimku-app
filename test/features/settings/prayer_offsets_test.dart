import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:muslimku/core/network/api_service.dart';
import 'package:muslimku/core/storage/local_store.dart';
import 'package:muslimku/core/time/clock_provider.dart';
import 'package:muslimku/features/prayer/application/adzan_provider.dart';
import 'package:muslimku/features/prayer/application/prayer_offsets_provider.dart';
import 'package:muslimku/features/prayer/application/prayer_time_provider.dart';
import 'package:muslimku/features/prayer/data/reminder_gateway.dart';
import 'package:muslimku/features/prayer/domain/adzan_plan.dart';
import 'package:muslimku/features/prayer/domain/prayer_offsets.dart';
import 'package:muslimku/features/prayer/presentation/monthly_schedule_screen.dart';
import 'package:muslimku/features/settings/presentation/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_home_api.dart';
import 'settings_adzan_test.dart' show FakeGateway;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => initializeDateFormatting('id_ID', null));
  setUp(() => SharedPreferences.setMockInitialValues({}));

  final day = FakeHomeApi.jadwal.jadwal; // imsak 03:39, subuh 03:49, isya 18:40

  test('apply shifts each prayer by its minutes; Imsak follows Subuh', () {
    const offsets = PrayerOffsets({
      AdzanPrayer.subuh: 2,
      AdzanPrayer.maghrib: -1,
      AdzanPrayer.isya: 3,
    });
    final s = offsets.apply(day);
    expect(s.subuh, '03:51');
    expect(s.imsak, '03:41', reason: 'Imsak keeps its 10 minutes before Subuh');
    expect(s.dzuhur, day.dzuhur);
    expect(s.ashar, day.ashar);
    expect(s.maghrib, '17:28');
    expect(s.isya, '18:43');
    expect(s.terbit, day.terbit);
    expect(s.date, day.date);
    expect(identical(PrayerOffsets.none.apply(day), day), isTrue);
  });

  test('shifting wraps around midnight and ignores bad times', () {
    expect(shiftHhmm('23:58', 5), '00:03');
    expect(shiftHhmm('00:02', -5), '23:57');
    expect(shiftHhmm('-', 5), '-');
    expect(shiftHhmm('', 5), '');
  });

  test('summary, json and limits', () {
    const offsets = PrayerOffsets({
      AdzanPrayer.subuh: 2,
      AdzanPrayer.maghrib: -1,
    });
    expect(offsets.summary, 'Subuh +2 · Maghrib −1');
    expect(PrayerOffsets.none.summary, 'Belum ada koreksi');
    expect(PrayerOffsets.fromJson(offsets.toJson()), offsets);
    expect(offsets.of(AdzanPrayer.isya), 0);
    expect(PrayerOffsets.limit, 15);
    // Out-of-range values are clamped when set.
    expect(offsets.set(AdzanPrayer.isya, 40).of(AdzanPrayer.isya), 15);
    expect(offsets.set(AdzanPrayer.isya, -40).of(AdzanPrayer.isya), -15);
    expect(offsets.set(AdzanPrayer.subuh, 0).of(AdzanPrayer.subuh), 0);
  });

  test('the provider saves and restores the offsets', () async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final n = c.read(prayerOffsetsProvider.notifier);
    await n.ready;
    expect(c.read(prayerOffsetsProvider), PrayerOffsets.none);
    await n.set(AdzanPrayer.subuh, 2);
    await n.set(AdzanPrayer.isya, -3);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(PrayerOffsetsNotifier.key), isNotNull);

    final again = ProviderContainer();
    addTearDown(again.dispose);
    await again.read(prayerOffsetsProvider.notifier).ready;
    expect(again.read(prayerOffsetsProvider).of(AdzanPrayer.subuh), 2);
    expect(again.read(prayerOffsetsProvider).of(AdzanPrayer.isya), -3);
    await again.read(prayerOffsetsProvider.notifier).reset();
    expect(again.read(prayerOffsetsProvider), PrayerOffsets.none);
  });

  test('today on the Beranda and the adzan plan follow the offsets', () async {
    final gateway = FakeGateway();
    final c = ProviderContainer(
      overrides: [
        apiServiceProvider.overrideWithValue(FakeHomeApi()),
        localStoreProvider.overrideWithValue(MemoryLocalStore()),
        reminderGatewayProvider.overrideWithValue(gateway),
        nowProvider.overrideWithValue(() => DateTime(2026, 10, 25, 18, 2)),
      ],
    );
    addTearDown(c.dispose);
    c.listen(prayerTimeProvider, (_, _) {});
    c.listen(adzanProvider, (_, _) {});
    await c.read(prayerOffsetsProvider.notifier).ready;
    await c.read(prayerTimeProvider.notifier).loadPrayerTimes();
    expect(c.read(prayerTimeProvider).prayerTime!.jadwal.isya, '18:40');

    await c.read(prayerOffsetsProvider.notifier).set(AdzanPrayer.isya, 3);
    await Future<void>.delayed(Duration.zero);
    expect(
      c.read(prayerTimeProvider).prayerTime!.jadwal.isya,
      '18:43',
      reason: 'the loaded day is re-shifted without a new request',
    );

    final adzan = c.read(adzanProvider.notifier);
    await adzan.ready;
    await adzan.setEnabled(true);
    await Future<void>.delayed(Duration.zero);
    final isya = gateway.scheduled.firstWhere(
      (r) => r.prayer == AdzanPrayer.isya && !r.early,
    );
    expect(isya.at.hour * 60 + isya.at.minute, 18 * 60 + 43);
    expect(isya.body, startsWith('Isya 18:43'));
  });

  testWidgets('Pengaturan > Koreksi waktu sholat with steppers', (
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
    expect(find.text('Koreksi waktu sholat'), findsOneWidget);
    expect(find.text('Belum ada koreksi'), findsOneWidget);
    await tester.tap(find.text('Koreksi waktu sholat'));
    await tester.pumpAndSettle();
    expect(find.text('Atur ulang'), findsOneWidget);
    await tester.tap(find.byTooltip('Subuh 1 menit lebih lambat'));
    await tester.pump();
    await tester.tap(find.byTooltip('Subuh 1 menit lebih lambat'));
    await tester.pump();
    await tester.tap(find.byTooltip('Maghrib 1 menit lebih cepat'));
    await tester.pumpAndSettle();
    expect(find.text('+2'), findsOneWidget);
    expect(find.text('−1'), findsOneWidget);
    await tester.tapAt(const Offset(195, 40));
    await tester.pumpAndSettle();
    expect(find.text('Subuh +2 · Maghrib −1'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(PrayerOffsetsNotifier.key), contains('subuh'));
  });

  testWidgets('Jadwal sebulan shows the corrected times', (tester) async {
    SharedPreferences.setMockInitialValues({
      PrayerOffsetsNotifier.key: const PrayerOffsets({
        AdzanPrayer.subuh: 5,
      }).toJson(),
    });
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiServiceProvider.overrideWithValue(FakeHomeApi()),
          localStoreProvider.overrideWithValue(MemoryLocalStore()),
          clockProvider.overrideWith(
            (ref) => Stream.value(DateTime(2026, 10, 25, 18, 2)),
          ),
        ],
        child: const MaterialApp(
          home: MonthlyScheduleScreen(cityId: '1632', city: 'Kota Kediri'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('03:54'), findsWidgets, reason: 'Subuh 03:49 + 5');
    expect(find.text('03:49'), findsNothing);
    expect(find.text('03:44'), findsWidgets, reason: 'Imsak follows');
  });

  test('PrayerTimeModel keeps id/lokasi when the day is replaced', () {
    final shifted = FakeHomeApi.jadwal.withJadwal(
      const PrayerOffsets({AdzanPrayer.subuh: 1}).apply(day),
    );
    expect(shifted.id, FakeHomeApi.jadwal.id);
    expect(shifted.lokasi, FakeHomeApi.jadwal.lokasi);
    expect(shifted.jadwal.subuh, '03:50');
  });
}
