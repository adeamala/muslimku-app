import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muslimku/core/theme/app_theme.dart';
import 'package:muslimku/features/tasbih/presentation/tasbih_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _pump(WidgetTester tester) async {
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
        home: const TasbihScreen(),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('tapping the dial counts and walks through the dzikir', (
    tester,
  ) async {
    await _pump(tester);
    expect(find.text('0'), findsOneWidget);
    expect(find.text('dari 33'), findsOneWidget);
    expect(find.text('Subhanallah'), findsOneWidget);

    for (var i = 0; i < 33; i++) {
      await tester.tap(find.text('dari 33'));
    }
    await tester.pump();
    expect(find.text('33'), findsOneWidget);
    expect(find.text('Putaran selesai: 1'), findsOneWidget);

    await tester.tap(find.text('dari 33'));
    await tester.pump();
    expect(find.text('1'), findsOneWidget);
    expect(find.text('Alhamdulillah'), findsOneWidget);
  });

  testWidgets('free counting has no target', (tester) async {
    await _pump(tester);
    await tester.tap(find.text('Bebas'));
    await tester.pump();
    expect(find.text('tanpa target'), findsOneWidget);
    expect(find.text('Ketuk lingkaran untuk menghitung'), findsOneWidget);
  });

  testWidgets('reset asks first', (tester) async {
    await _pump(tester);
    await tester.tap(find.text('dari 33'));
    await tester.pump();
    await tester.tap(find.byTooltip('Ulangi dari nol'));
    await tester.pumpAndSettle();
    expect(find.text('Ulangi dari nol?'), findsOneWidget);
    await tester.tap(find.text('Ulangi'));
    await tester.pumpAndSettle();
    expect(find.text('0'), findsOneWidget);
  });
}
