import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:muslimku/core/theme/app_colors.dart';
import 'package:muslimku/core/theme/app_theme.dart';
import 'package:muslimku/features/app_update/application/app_update_provider.dart';
import 'package:muslimku/features/app_update/data/app_update_gateway.dart';
import 'package:muslimku/features/app_update/presentation/app_update_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_app_update_gateway.dart';
import '../../support/pump_home.dart';

Future<void> _settleSheet(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
}

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('home offers the update, downloads it, then installs', (
    tester,
  ) async {
    final play = FakeAppUpdateGateway(
      update: const AvailableUpdate(versionCode: 10),
    );
    await pumpHome(
      tester,
      overrides: [appUpdateGatewayProvider.overrideWithValue(play)],
    );
    await _settleSheet(tester);

    expect(find.text('Pembaruan tersedia'), findsOneWidget);
    expect(find.text('Diunduh di latar belakang'), findsOneWidget);

    await tester.tap(find.text('Perbarui sekarang'));
    await _settleSheet(tester);
    expect(find.text('Pembaruan tersedia'), findsNothing);
    expect(find.text('Mengunduh pembaruan…'), findsOneWidget);
    expect(play.downloads, 1);

    play.downloadResult.complete(UpdateDownloadResult.downloaded);
    await _settleSheet(tester);
    expect(find.text('Pembaruan siap'), findsOneWidget);

    await tester.tap(find.text('Pasang'));
    await tester.pump();
    expect(play.installs, 1);
  });

  testWidgets('"Nanti saja" closes the sheet and snoozes the version', (
    tester,
  ) async {
    final play = FakeAppUpdateGateway(
      update: const AvailableUpdate(versionCode: 10),
    );
    await pumpHome(
      tester,
      overrides: [appUpdateGatewayProvider.overrideWithValue(play)],
    );
    await _settleSheet(tester);

    await tester.tap(find.text('Nanti saja'));
    await _settleSheet(tester);
    expect(find.text('Pembaruan tersedia'), findsNothing);
    expect(find.text('Mengunduh pembaruan…'), findsNothing);
    expect(play.downloads, 0);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt(AppUpdateNotifier.snoozeKey(10)), isNotNull);
  });

  testWidgets('no sheet when the app is up to date', (tester) async {
    final play = FakeAppUpdateGateway();
    await pumpHome(
      tester,
      overrides: [appUpdateGatewayProvider.overrideWithValue(play)],
    );
    await _settleSheet(tester);
    expect(play.checks, 1);
    expect(find.text('Pembaruan tersedia'), findsNothing);
  });

  for (final dark in [false, true]) {
    testWidgets(
      'sheet and banners fit a small phone at 130 % text (dark: $dark)',
      (tester) async {
        AppColors.dark = dark;
        addTearDown(() => AppColors.dark = false);
        tester.view.physicalSize = const Size(320 * 3, 640 * 3);
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          MaterialApp(
            theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.3)),
              child: child!,
            ),
            home: Scaffold(
              body: ListView(
                children: [
                  const AppUpdateSheet(
                    update: AvailableUpdate(versionCode: 10, priority: 5),
                  ),
                  for (final phase in [
                    UpdatePhase.downloading,
                    UpdatePhase.ready,
                  ])
                    AppUpdateBanner(
                      phase: phase,
                      onInstall: () {},
                      onClose: () {},
                    ),
                ],
              ),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(find.text('Pembaruan penting tersedia'), findsOneWidget);
        expect(find.text('PENTING'), findsOneWidget);
      },
    );
  }
}
