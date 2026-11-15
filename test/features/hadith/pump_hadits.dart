import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muslimku/core/network/api_service.dart';
import 'package:muslimku/core/storage/local_store.dart';
import 'package:muslimku/core/theme/app_theme.dart';
import 'package:muslimku/core/time/clock_provider.dart';
import 'package:muslimku/features/hadith/presentation/hadith_screen.dart';

import '../../support/fake_hadits_api.dart';

/// Pumps [home] (the Hadits tab by default) at phone size with [FakeHaditsApi]
/// on 25 Oct 2026, animations off.
Future<FakeHaditsApi> pumpHadits(
  WidgetTester tester, {
  Widget? home,
  FakeHaditsApi? api,
  LocalStore? store,
  double textScale = 1,
}) async {
  final fake = api ?? FakeHaditsApi();
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        apiServiceProvider.overrideWithValue(fake),
        localStoreProvider.overrideWithValue(store ?? MemoryLocalStore()),
        clockProvider.overrideWith(
          (ref) => Stream.value(DateTime(2026, 10, 25, 18, 2)),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            disableAnimations: true,
            textScaler: TextScaler.linear(textScale),
          ),
          child: child!,
        ),
        home: home ?? const Scaffold(body: HadithScreen()),
      ),
    ),
  );
  await settleHadits(tester);
  return fake;
}

Future<void> settleHadits(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}
