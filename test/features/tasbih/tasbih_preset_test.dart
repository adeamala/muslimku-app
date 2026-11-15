import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muslimku/core/theme/app_theme.dart';
import 'package:muslimku/features/tasbih/application/tasbih_provider.dart';
import 'package:muslimku/features/tasbih/presentation/tasbih_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _quddus = TasbihPreset(arabic: 'الْقُدُّوْسُ', latin: 'Al-Quddûsu');

Future<void> _pump(WidgetTester tester, Widget screen) async {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: screen,
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('a preset shows the name instead of the dzikir after salat', (
    tester,
  ) async {
    await _pump(tester, const TasbihScreen(preset: _quddus));
    expect(find.text('Al-Quddûsu'), findsOneWidget);
    expect(find.text('الْقُدُّوْسُ'), findsOneWidget);
    expect(find.text('Subhanallah'), findsNothing);
    expect(find.text('dari 33'), findsOneWidget);

    for (var i = 0; i < 34; i++) {
      await tester.tap(find.text('dari 33'));
    }
    await tester.pump();
    expect(find.text('Putaran selesai: 1'), findsOneWidget);
    expect(find.text('Al-Quddûsu'), findsOneWidget);
    expect(find.text('Alhamdulillah'), findsNothing);
  });

  testWidgets('a preset counts on its own and keeps the saved counter', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'tasbih_count': 40,
      'tasbih_target': 99,
    });
    await _pump(tester, const TasbihScreen(preset: _quddus));
    expect(find.text('0'), findsOneWidget);
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('dari 33'));
    }
    await tester.pump();
    expect(find.text('3'), findsOneWidget);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('tasbih_count'), 40);
    expect(prefs.getInt('tasbih_target'), 99);
  });

  testWidgets('without a preset the saved counter is used as before', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'tasbih_count': 5});
    await _pump(tester, const TasbihScreen());
    expect(find.text('5'), findsOneWidget);
    expect(find.text('Subhanallah'), findsOneWidget);
  });

  test('a session notifier starts at zero with the preset target', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    const preset = TasbihPreset(arabic: 'x', latin: 'x');
    final provider = tasbihSessionProvider(preset);
    final sub = container.listen(provider, (_, _) {});
    addTearDown(sub.close);
    expect(
      (container.read(provider).count, container.read(provider).target),
      (0, 33),
    );
    container.read(provider.notifier).increment();
    expect(container.read(provider).count, 1);
    await Future<void>.delayed(Duration.zero);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('tasbih_count'), isNull);
  });
}
