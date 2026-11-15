import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:muslimku/app/app.dart';
import 'package:muslimku/core/network/api_service.dart';
import 'package:muslimku/core/storage/local_store.dart';
import 'package:muslimku/core/theme/app_colors.dart';
import 'package:muslimku/core/theme/app_theme_provider.dart';
import 'package:muslimku/features/prayer/data/reminder_gateway.dart';
import 'package:muslimku/features/settings/presentation/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_home_api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => initializeDateFormatting('id_ID', null));
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppColors.dark = false;
  });
  tearDown(() => AppColors.dark = false);

  test('modes: labels, ThemeMode and what counts as dark', () {
    expect(AppThemeMode.values.map((m) => m.label), [
      'Ikuti HP',
      'Terang',
      'Gelap',
    ]);
    expect(AppThemeMode.sistem.themeMode, ThemeMode.system);
    expect(AppThemeMode.gelap.themeMode, ThemeMode.dark);
    expect(AppThemeMode.sistem.isDark(Brightness.dark), isTrue);
    expect(AppThemeMode.sistem.isDark(Brightness.light), isFalse);
    expect(AppThemeMode.terang.isDark(Brightness.dark), isFalse);
    expect(AppThemeMode.gelap.isDark(Brightness.light), isTrue);
    expect(AppThemeMode.byName('gelap'), AppThemeMode.gelap);
    expect(AppThemeMode.byName(null), AppThemeMode.sistem);
  });

  test('the choice is saved as app_theme', () async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final n = c.read(appThemeProvider.notifier);
    await n.ready;
    expect(c.read(appThemeProvider), AppThemeMode.sistem);
    await n.set(AppThemeMode.gelap);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(AppThemeNotifier.key), 'gelap');
  });

  test('the palette tokens follow AppColors.dark', () {
    final lightInk = AppColors.ink;
    final lightSurface = AppColors.surface;
    AppColors.dark = true;
    expect(AppColors.ink, isNot(lightInk));
    expect(AppColors.surface, isNot(lightSurface));
    expect(AppColors.surface.computeLuminance(), lessThan(0.1));
    expect(AppColors.ink.computeLuminance(), greaterThan(0.8));
    expect(AppColors.stageBackground.computeLuminance(), lessThan(0.05));
    // Brand colours never move.
    expect(AppColors.secondary, const Color(0xFF5A45FE));
    expect(AppColors.primary, const Color(0xFFD2F801));
  });

  testWidgets('Pengaturan > Tema aplikasi switches the app to dark', (
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
          reminderGatewayProvider.overrideWithValue(const NoReminderGateway()),
        ],
        child: const MuslimkuApp(),
      ),
    );
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(AppColors.dark, isFalse);

    // Jump straight to Pengaturan.
    final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
    unawaited(
      nav.push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen())),
    );
    await tester.pumpAndSettle();
    expect(find.text('Tema aplikasi'), findsOneWidget);
    expect(find.text('Ikuti HP'), findsOneWidget);
    await tester.tap(find.text('Tema aplikasi'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gelap').last);
    await tester.pumpAndSettle();
    expect(AppColors.dark, isTrue);
    Navigator.of(tester.element(find.text('Gelap').last)).pop();
    await tester.pumpAndSettle();
    // The settings page itself is now painted on the night background.
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).last);
    expect(scaffold.backgroundColor, AppColors.stageBackground);
    expect(scaffold.backgroundColor!.computeLuminance(), lessThan(0.05));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(AppThemeNotifier.key), 'gelap');
    // Back to light: the tokens flip back.
    await tester.tap(find.text('Tema aplikasi'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Terang').last);
    await tester.pumpAndSettle();
    expect(AppColors.dark, isFalse);
    Navigator.of(tester.element(find.text('Terang').last)).pop();
    await tester.pumpAndSettle();
  });
}
