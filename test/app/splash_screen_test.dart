import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:muslimku/app/shell/home_screen.dart';
import 'package:muslimku/app/splash_screen.dart';
import 'package:muslimku/core/network/api_service.dart';
import 'package:muslimku/core/theme/app_theme.dart';
import 'package:muslimku/core/time/clock_provider.dart';
import 'package:muslimku/features/onboarding/presentation/onboarding_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_home_api.dart';

void main() {
  setUpAll(() => initializeDateFormatting('id_ID', null));
  // A returning user (city saved) goes straight to Beranda.
  setUp(
    () => SharedPreferences.setMockInitialValues({'selectedCityId': '1632'}),
  );

  Future<void> pumpSplash(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiServiceProvider.overrideWithValue(FakeHomeApi()),
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
          home: const SplashScreen(),
        ),
      ),
    );
  }

  testWidgets('opens Beranda within 1.5 s, without the old 2.2 s wait', (
    tester,
  ) async {
    await pumpSplash(tester);

    // The M mark sits at the system splash's 288 dp, shown at once, not
    // faded in from white; the old full-screen 3D wordmark is gone.
    final mark = tester.widget<Image>(find.byType(Image));
    expect((mark.image as AssetImage).assetName, SplashScreen.markAsset);
    expect(tester.getSize(find.byType(Image)), const Size(288, 288));
    expect(
      tester.getCenter(find.byType(Image)),
      tester.getCenter(find.byType(Scaffold)),
    );
    expect(find.text('Muslimku', findRichText: true), findsOneWidget);
    expect(
      tester
          .widgetList<Opacity>(find.byType(Opacity))
          .where((o) => o.opacity < 1),
      isEmpty,
    );

    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(HomeScreen), findsNothing);

    for (var i = 0; i < 13; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('a fresh install gets the onboarding first', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await pumpSplash(tester);
    for (var i = 0; i < 17; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
  });
}
