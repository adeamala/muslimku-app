import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:muslimku/app/shell/bottom_navigation_bar.dart';
import 'package:muslimku/app/shell/home_screen.dart';
import 'package:muslimku/core/network/api_service.dart';
import 'package:muslimku/core/storage/local_store.dart';
import 'package:muslimku/core/theme/app_theme.dart';
import 'package:muslimku/core/time/clock_provider.dart';
import 'package:muslimku/features/home/presentation/widgets/ibadah_grid.dart';
import 'package:muslimku/features/home/presentation/widgets/prayer_timeline.dart';
import 'package:muslimku/features/quran/presentation/quran_screen.dart';
import 'package:muslimku/features/tasbih/presentation/tasbih_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_home_api.dart';

final _evening = DateTime(2026, 10, 25, 18, 2, 12);

Future<FakeHomeApi> _pumpHome(
  WidgetTester tester, {
  FakeHomeApi? api,
  DateTime? now,
}) async {
  final fake = api ?? FakeHomeApi();
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        apiServiceProvider.overrideWithValue(fake),
        // The Arbain card reads the saved Arbain list (ContentCache).
        localStoreProvider.overrideWithValue(MemoryLocalStore()),
        clockProvider.overrideWith((ref) => Stream.value(now ?? _evening)),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: const HomeScreen(),
      ),
    ),
  );
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  return fake;
}

Finder _inGrid(String label) =>
    find.descendant(of: find.byType(IbadahGrid), matching: find.text(label));

void main() {
  setUpAll(() => initializeDateFormatting('id_ID', null));
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('stage shows city, both dates and the next prayer countdown', (
    tester,
  ) async {
    await _pumpHome(tester);

    expect(find.text('Kota Kediri'), findsOneWidget);
    expect(find.textContaining('Minggu, 25 Oktober 2026'), findsOneWidget);
    expect(find.textContaining('13 Jumadil Awal 1448 H'), findsOneWidget);
    expect(find.text('WAKTU BERIKUTNYA'), findsOneWidget);
    expect(find.text('38 menit lagi'), findsOneWidget);
    // Isya appears in the stage, on the timeline and as a "Sudah sholat" chip.
    expect(find.text('Isya'), findsNWidgets(3));
    expect(find.text('18:40'), findsNWidgets(2));
  });

  testWidgets('after Isya the stage counts down to tomorrow\'s Subuh', (
    tester,
  ) async {
    await _pumpHome(tester, now: DateTime(2026, 10, 25, 21, 0));
    expect(find.text('BESOK'), findsOneWidget);
    expect(find.text('6 jam 49 menit lagi'), findsOneWidget);
  });

  testWidgets('timeline shows the six times and Imsak', (tester) async {
    await _pumpHome(tester);
    final timeline = find.byType(PrayerTimeline);
    for (final label in ['Subuh', 'Terbit', 'Dzuhur', 'Ashar', 'Maghrib']) {
      expect(
        find.descendant(of: timeline, matching: find.text(label)),
        findsOneWidget,
        reason: label,
      );
    }
    expect(find.text('05:03'), findsOneWidget);
    expect(find.text('Imsak 03:39'), findsOneWidget);
  });

  testWidgets('Ibadah grid marks the new features and opens Tasbih', (
    tester,
  ) async {
    await _pumpHome(tester);
    expect(find.text('BARU'), findsNWidgets(3));

    await tester.ensureVisible(_inGrid('Tasbih'));
    await tester.tap(_inGrid('Tasbih'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(TasbihScreen), findsOneWidget);
  });

  testWidgets("Al-Qur'an tile switches to the Qur'an tab", (tester) async {
    await _pumpHome(tester);
    await tester.ensureVisible(_inGrid("Al-Qur'an"));
    await tester.tap(_inGrid("Al-Qur'an"));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(QuranScreen), findsOneWidget);
  });

  testWidgets('daily cards show the verse, hadith, doa and Asmaul Husna', (
    tester,
  ) async {
    await _pumpHome(tester);
    expect(find.text('AYAT PILIHAN'), findsOneWidget);
    expect(find.text("QS. Ar-Ra'd : 28"), findsOneWidget);
    // The Arbain is "Hadits hari ini" (No. 4 on 25 Oct), not a random one.
    expect(find.text('Takdir Setiap Manusia sudah Tertulis'), findsOneWidget);
    expect(find.text('Hadits Arbain ke-4'), findsOneWidget);
    expect(find.text('Doa Mohon Kebaikan Dunia dan Akhirat'), findsOneWidget);
    expect(find.text('Yang Maha Tunggal'), findsOneWidget);

    await tester.ensureVisible(find.text('Bulughul Maram'));
    await tester.tap(find.text('Bulughul Maram'));
    await tester.pump();
    expect(find.text('Bulughul Maram no. 120'), findsOneWidget);
  });

  testWidgets('Beranda and the Hadits tab show the same hadith of the day', (
    tester,
  ) async {
    final api = await _pumpHome(tester);
    expect(find.text('Hadits Arbain ke-4'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(CustomBottomNavigationBar),
        matching: find.text('Hadits'),
      ),
    );
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.text('HADITS HARI INI · NO. 4'), findsOneWidget);
    expect(api.arbainListCalls, 1, reason: 'the tab reuses the list');
  });

  testWidgets('without the Arbain list Beranda keeps the random Arbain', (
    tester,
  ) async {
    await _pumpHome(tester, api: FakeHomeApi(failArbainList: true));
    expect(
      find.text('Allah Mahabaik dan Hanya Menerima yang Baik'),
      findsOneWidget,
    );
    expect(find.text('Hadits Arbain ke-10'), findsOneWidget);
  });

  testWidgets('pulling Beranda down retries a failed Arbain list', (
    tester,
  ) async {
    final api = await _pumpHome(tester, api: FakeHomeApi(failArbainList: true));
    expect(find.text('Hadits Arbain ke-10'), findsOneWidget);
    expect(api.arbainListCalls, 1);

    // Back online: the refresh also brings back "Hadits hari ini".
    api.failArbainList = false;
    await tester.fling(
      find
          .descendant(
            of: find.byType(RefreshIndicator),
            matching: find.byType(Scrollable),
          )
          .first,
      const Offset(0, 400),
      1000,
    );
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(api.arbainListCalls, 2);
    expect(find.text('Hadits Arbain ke-4'), findsOneWidget);
    expect(find.text('Takdir Setiap Manusia sudah Tertulis'), findsOneWidget);
  });

  testWidgets('a failed schedule offers a retry that reloads it', (
    tester,
  ) async {
    final api = FakeHomeApi(failPrayerTimes: true);
    await _pumpHome(tester, api: api);
    expect(find.text('Coba lagi'), findsOneWidget);
    expect(find.text('38 menit lagi'), findsNothing);

    api.failPrayerTimes = false;
    await tester.tap(find.text('Coba lagi'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('38 menit lagi'), findsOneWidget);
  });

  testWidgets('bottom bar labels', (tester) async {
    await _pumpHome(tester);
    for (final label in [
      'Beranda',
      "Al-Qur'an",
      'Hadits',
      'Asmaul Husna',
      'Doa',
    ]) {
      expect(find.text(label), findsWidgets, reason: label);
    }
  });
}
