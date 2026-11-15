import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:muslimku/core/network/api_service.dart';
import 'package:muslimku/core/storage/local_store.dart';
import 'package:muslimku/core/theme/app_theme.dart';
import 'package:muslimku/core/time/clock_provider.dart';
import 'package:muslimku/features/prayer/data/prayer_schedule_repository.dart';
import 'package:muslimku/features/prayer/presentation/monthly_schedule_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_home_api.dart';
import '../../support/pump_home.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => initializeDateFormatting('id_ID', null));
  setUp(() => SharedPreferences.setMockInitialValues({}));

  final october = DateTime(2026, 10, 25, 18, 2);

  test('monthScheduleText lists the month for sharing', () {
    final month = PrayerMonth.fromJson({
      'id': '1632',
      'lokasi': 'KOTA KEDIRI',
      'daerah': 'JAWA TIMUR',
      'jadwal': [
        {...FakeHomeApi.jadwal.jadwal.toJson(), 'date': '2026-10-01'},
        {...FakeHomeApi.jadwal.jadwal.toJson(), 'date': '2026-10-02'},
      ],
    });
    final text = monthScheduleText(month, DateTime(2026, 10));
    expect(text, startsWith('Jadwal sholat Kota Kediri · Oktober 2026\n'));
    expect(text, contains('Tgl  Imsak Subuh Dzuhur Ashar Maghrib Isya\n'));
    expect(text, contains('\n 1   03:39 03:49 11:20  14:29 17:29   18:40\n'));
    expect(text, endsWith('Sumber: MyQuran · Muslimku'));
  });

  Future<FakeHomeApi> pumpMonth(
    WidgetTester tester, {
    bool offline = false,
    MemoryLocalStore? store,
  }) async {
    final api = FakeHomeApi()..failPrayerTimes = offline;
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiServiceProvider.overrideWithValue(api),
          localStoreProvider.overrideWithValue(store ?? MemoryLocalStore()),
          clockProvider.overrideWith((ref) => Stream.value(october)),
          nowProvider.overrideWithValue(() => october),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const MonthlyScheduleScreen(
            cityId: '1632',
            city: 'Kota Kediri',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return api;
  }

  testWidgets('shows the month as a table with today marked', (tester) async {
    final api = await pumpMonth(tester);
    expect(find.text('Jadwal sebulan'), findsOneWidget);
    expect(find.text('Oktober 2026'), findsOneWidget);
    expect(find.text('Kota Kediri'), findsOneWidget);
    expect(api.jsonPaths, ['sholat/jadwal/1632/2026/10']);
    // Column headers, then 31 rows.
    for (final h in ['Imsak', 'Subuh', 'Dzuhur', 'Ashar', 'Maghrib', 'Isya']) {
      expect(find.text(h), findsOneWidget);
    }
    expect(find.byKey(const ValueKey('day-2026-10-01')), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('day-2026-10-31')),
      300,
    );
    expect(find.byKey(const ValueKey('day-2026-10-31')), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp('hari ini')),
      findsOneWidget,
      reason: 'today (25) is marked',
    );
  });

  testWidgets('flips to the next month and back', (tester) async {
    final api = await pumpMonth(tester);
    await tester.tap(find.byTooltip('Bulan depan'));
    await tester.pumpAndSettle();
    expect(find.text('November 2026'), findsOneWidget);
    expect(api.jsonPaths.last, 'sholat/jadwal/1632/2026/11');
    expect(find.byKey(const ValueKey('day-2026-11-30')), findsOneWidget);
    await tester.tap(find.byTooltip('Bulan lalu'));
    await tester.pumpAndSettle();
    expect(find.text('Oktober 2026'), findsOneWidget);
    // Months are kept, not fetched twice.
    expect(api.jsonPaths.where((p) => p.endsWith('/10')), hasLength(1));
  });

  testWidgets('offline shows the saved month and an empty state otherwise', (
    tester,
  ) async {
    final store = MemoryLocalStore();
    // Save October first.
    await pumpMonth(tester, store: store);
    await tester.pumpWidget(const SizedBox());
    await pumpMonth(tester, offline: true, store: store);
    expect(find.text('Oktober 2026'), findsOneWidget);
    expect(find.byKey(const ValueKey('day-2026-10-01')), findsOneWidget);
    await tester.tap(find.byTooltip('Bulan depan'));
    await tester.pumpAndSettle();
    expect(find.text('November 2026'), findsOneWidget);
    expect(find.text('Jadwal belum tersimpan'), findsOneWidget);
    expect(find.text('Coba lagi'), findsOneWidget);
  });

  testWidgets('shares the month as text', (tester) async {
    final shared = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/share'),
      (call) async {
        shared.add((call.arguments as Map)['text'] as String);
        return 'dev.fluttercommunity.plus/share/success';
      },
    );
    await pumpMonth(tester);
    await tester.tap(find.byTooltip('Bagikan jadwal'));
    await tester.pumpAndSettle();
    expect(shared, hasLength(1));
    expect(
      shared.single,
      startsWith('Jadwal sholat Kota Kediri · Oktober 2026'),
    );
  });

  testWidgets('nothing clips at 130% text', (tester) async {
    final api = FakeHomeApi();
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiServiceProvider.overrideWithValue(api),
          localStoreProvider.overrideWithValue(MemoryLocalStore()),
          clockProvider.overrideWith((ref) => Stream.value(october)),
          nowProvider.overrideWithValue(() => october),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.3)),
            child: child!,
          ),
          home: const MonthlyScheduleScreen(
            cityId: '1632',
            city: 'Kota Kediri',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // Every header label and time is laid out in full (a FittedBox scales
    // it down) rather than cut off by its column.
    for (final label in [
      'Imsak',
      'Subuh',
      'Dzuhur',
      'Ashar',
      'Maghrib',
      'Isya',
      '03:39',
    ]) {
      final paragraph = tester.renderObject<RenderParagraph>(
        find.text(label).first,
      );
      expect(
        paragraph.didExceedMaxLines,
        isFalse,
        reason: '$label is clipped at 130%',
      );
      expect(
        paragraph.textSize.width,
        lessThanOrEqualTo(paragraph.size.width + 0.5),
        reason: '$label is clipped at 130%',
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('Beranda opens it from "Jadwal hari ini"', (tester) async {
    await pumpHome(tester);
    await tester.tap(find.text('Sebulan'));
    await tester.pumpAndSettle();
    expect(find.text('Jadwal sebulan'), findsOneWidget);
    expect(find.text('Oktober 2026'), findsOneWidget);
  });
}
