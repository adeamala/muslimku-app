import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muslimku/features/asmaul_husna/application/husna_quiz_provider.dart';
import 'package:muslimku/features/asmaul_husna/presentation/husna_quiz_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_husna_doa_api.dart';

Future<ProviderContainer> _pumpQuiz(WidgetTester tester) async {
  await pumpSenja(
    tester,
    const HusnaQuizScreen(),
    api: FakeHusnaDoaApi(),
    overrides: [husnaQuizRandomProvider.overrideWithValue(Random(7))],
  );
  return ProviderScope.containerOf(
    tester.element(find.byType(HusnaQuizScreen)),
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('a right answer turns lime, explains the name and scores', (
    tester,
  ) async {
    final container = await _pumpQuiz(tester);
    final q = container.read(husnaQuizProvider).question!;
    expect(find.text('1/13'), findsOneWidget);
    expect(find.text('Apa arti nama ini?'), findsOneWidget);
    expect(find.text('No. ${q.name.number}'), findsOneWidget);
    expect(find.text('Benar 0 dari 0'), findsOneWidget);

    await tester.tap(find.text(q.options[q.answer]));
    await tester.pump();
    expect(
      find.text('Benar! ${q.name.latin} artinya ${q.name.meaning}.'),
      findsOneWidget,
    );
    expect(find.text('Benar 1 dari 1'), findsOneWidget);
    expect(find.text('1 hari beruntun'), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsNWidgets(2));

    await tester.ensureVisible(find.text('Lanjut'));
    await tester.tap(find.text('Lanjut'));
    await tester.pump();
    expect(find.text('2/13'), findsOneWidget);
    expect(find.textContaining('artinya'), findsNothing);
  });

  testWidgets('a wrong pick is marked and the right meaning is shown', (
    tester,
  ) async {
    final container = await _pumpQuiz(tester);
    final q = container.read(husnaQuizProvider).question!;
    final wrong = (q.answer + 1) % q.options.length;

    await tester.tap(find.text(q.options[wrong]));
    await tester.pump();
    expect(
      find.text('Belum tepat. ${q.name.latin} artinya ${q.name.meaning}.'),
      findsOneWidget,
    );
    expect(
      find.byIcon(Icons.close_rounded),
      findsNWidgets(2),
    ); // app bar + pick
    expect(find.text('Benar 0 dari 1'), findsOneWidget);

    // Further taps do nothing until Lanjut.
    await tester.tap(find.text(q.options[q.answer]));
    await tester.pump();
    expect(find.text('Benar 0 dari 1'), findsOneWidget);
  });
}
