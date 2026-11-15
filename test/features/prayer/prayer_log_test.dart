import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:muslimku/core/storage/local_store.dart';
import 'package:muslimku/core/time/clock_provider.dart';
import 'package:muslimku/features/prayer/application/prayer_log_provider.dart';
import 'package:muslimku/features/prayer/domain/adzan_plan.dart';
import 'package:muslimku/features/prayer/domain/prayer_log.dart';
import 'package:muslimku/features/prayer/presentation/prayer_log_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/pump_home.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => initializeDateFormatting('id_ID', null));
  setUp(() => SharedPreferences.setMockInitialValues({}));

  final today = DateTime(2026, 10, 25);
  DateTime d(int daysAgo) => today.subtract(Duration(days: daysAgo));
  final all = {...AdzanPrayer.values};

  test('toggle, done, and complete days', () {
    var log = PrayerLog.empty;
    expect(log.isDone(today, AdzanPrayer.subuh), isFalse);
    log = log.toggle(today, AdzanPrayer.subuh);
    expect(log.isDone(today, AdzanPrayer.subuh), isTrue);
    expect(log.doneOn(today), {AdzanPrayer.subuh});
    log = log.toggle(today, AdzanPrayer.subuh);
    expect(log.doneOn(today), isEmpty);
    expect(log.isComplete(today), isFalse);
    for (final p in AdzanPrayer.values) {
      log = log.toggle(today, p);
    }
    expect(log.isComplete(today), isTrue);
    expect(log.countOn(today), 5);
  });

  test('streak counts consecutive complete days, today or from yesterday', () {
    var log = PrayerLog.empty;
    for (final day in [d(1), d(2), d(3)]) {
      log = log.setDay(day, all);
    }
    expect(log.currentStreak(today), 3, reason: 'today not over yet');
    log = log.setDay(today, all);
    expect(log.currentStreak(today), 4);
    expect(log.longestStreak(today), 4);
    // A gap two days ago breaks the chain but not the record.
    log = log.setDay(d(2), {AdzanPrayer.subuh});
    expect(log.currentStreak(today), 2);
    expect(log.longestStreak(today), 2);
    log = log.setDay(d(5), all);
    log = log.setDay(d(6), all);
    log = log.setDay(d(7), all);
    expect(log.longestStreak(today), 3);
    expect(PrayerLog.empty.currentStreak(today), 0);
    // Yesterday missed: the streak is over even if earlier days were complete.
    final gone = PrayerLog.empty.setDay(d(2), all).setDay(d(3), all);
    expect(gone.currentStreak(today), 0);
  });

  test('last seven days and json round-trip', () {
    var log = PrayerLog.empty.setDay(today, {
      AdzanPrayer.subuh,
      AdzanPrayer.isya,
    });
    log = log.setDay(d(6), all);
    final week = log.lastDays(today, 7);
    expect(week.length, 7);
    expect(week.first.$1, d(6));
    expect(week.first.$2, 5);
    expect(week.last.$2, 2);
    final back = PrayerLog.fromJson(log.toJson());
    expect(back.doneOn(today), {AdzanPrayer.subuh, AdzanPrayer.isya});
    expect(back.countOn(d(6)), 5);
    // Empty days are not stored.
    expect(
      log.setDay(d(1), {}).toJson().containsKey(PrayerLog.key(d(1))),
      isFalse,
    );
  });

  test('the provider saves to the local store', () async {
    final store = MemoryLocalStore();
    final c = ProviderContainer(
      overrides: [localStoreProvider.overrideWithValue(store)],
    );
    addTearDown(c.dispose);
    final n = c.read(prayerLogProvider.notifier);
    await n.ready;
    await n.toggle(today, AdzanPrayer.dzuhur);
    expect(await store.readJson(PrayerLogNotifier.storeKey), isNotNull);

    final again = ProviderContainer(
      overrides: [localStoreProvider.overrideWithValue(store)],
    );
    addTearDown(again.dispose);
    await again.read(prayerLogProvider.notifier).ready;
    expect(
      again.read(prayerLogProvider).isDone(today, AdzanPrayer.dzuhur),
      isTrue,
    );
  });

  testWidgets(
    'Beranda: "Sudah sholat" chips mark the day and show the streak',
    (tester) async {
      // 18:02 on 25 Oct: Isya (18:40) has not come yet.
      await pumpHome(tester);
      await tester.scrollUntilVisible(find.text('Sudah sholat'), 200);
      await tester.pumpAndSettle();
      expect(find.text('0 dari 5'), findsOneWidget);
      expect(find.byTooltip('Tandai Subuh sudah'), findsOneWidget);
      expect(find.byTooltip('Isya belum masuk waktu'), findsOneWidget);
      await tester.tap(find.byTooltip('Tandai Subuh sudah'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Tandai Dzuhur sudah'));
      await tester.pumpAndSettle();
      expect(find.text('2 dari 5'), findsOneWidget);
      expect(find.byTooltip('Batalkan Subuh'), findsOneWidget);
      // The streak needs a complete day.
      expect(find.text('Belum ada rangkaian'), findsOneWidget);
      await tester.tap(find.text('Sudah sholat'));
      await tester.pumpAndSettle();
      expect(find.byType(PrayerLogScreen), findsOneWidget);
      expect(find.text('Catatan sholat'), findsOneWidget);
      expect(find.text('Hari ini 2 dari 5'), findsOneWidget);
    },
  );

  testWidgets('the log screen shows streaks and the last 30 days', (
    tester,
  ) async {
    final store = MemoryLocalStore();
    var log = PrayerLog.empty;
    for (var i = 1; i <= 3; i++) {
      log = log.setDay(d(i), all);
    }
    await store.writeJson(PrayerLogNotifier.storeKey, log.toJson());
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localStoreProvider.overrideWithValue(store),
          clockProvider.overrideWith(
            (ref) => Stream.value(DateTime(2026, 10, 25, 18, 2)),
          ),
        ],
        child: const MaterialApp(home: PrayerLogScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('3 hari berturut-turut'), findsOneWidget);
    expect(find.text('Terpanjang 3 hari'), findsOneWidget);
    expect(find.text('Hari ini 0 dari 5'), findsOneWidget);
    expect(find.byKey(const ValueKey('log-2026-10-24')), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('log-2026-09-26')),
      300,
    );
    expect(find.byKey(const ValueKey('log-2026-09-26')), findsOneWidget);
  });
}
