import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muslimku/app/shell/home_screen.dart';
import 'package:muslimku/core/network/api_service.dart';
import 'package:muslimku/core/storage/local_store.dart';
import 'package:muslimku/core/theme/app_theme.dart';
import 'package:muslimku/core/time/clock_provider.dart';
import 'package:muslimku/features/prayer/data/reminder_gateway.dart';

import 'fake_home_api.dart';

/// Pumps [HomeScreen] at phone size (390x844) with [FakeHomeApi] at 18:02 on
/// 25 Oct 2026 and animations disabled.
Future<FakeHomeApi> pumpHome(
  WidgetTester tester, {
  List<Override> overrides = const [],
}) async {
  final api = FakeHomeApi();
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        apiServiceProvider.overrideWithValue(api),
        localStoreProvider.overrideWithValue(MemoryLocalStore()),
        reminderGatewayProvider.overrideWithValue(const NoReminderGateway()),
        nowProvider.overrideWithValue(() => DateTime(2026, 10, 25, 18, 2)),
        ...overrides,
        clockProvider.overrideWith(
          (ref) => Stream.value(DateTime(2026, 10, 25, 18, 2)),
        ),
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
  await settle(tester);
  return api;
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}
