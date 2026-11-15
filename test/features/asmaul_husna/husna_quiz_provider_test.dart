import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muslimku/core/network/api_service.dart';
import 'package:muslimku/core/storage/local_store.dart';
import 'package:muslimku/features/asmaul_husna/application/husna_quiz_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_husna_doa_api.dart';

void main() {
  late FakeHusnaDoaApi api;
  late MemoryLocalStore store;
  late DateTime now;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    api = FakeHusnaDoaApi();
    store = MemoryLocalStore();
    now = DateTime(2026, 10, 25, 18, 2);
  });

  Future<ProviderContainer> open({int seed = 1}) async {
    final container = ProviderContainer(
      overrides: [
        apiServiceProvider.overrideWithValue(api),
        localStoreProvider.overrideWithValue(store),
        husnaQuizRandomProvider.overrideWithValue(Random(seed)),
        husnaQuizClockProvider.overrideWithValue(() => now),
      ],
    );
    addTearDown(container.dispose);
    container.listen(husnaQuizProvider, (_, _) {});
    await container.read(husnaQuizProvider.notifier).ready;
    return container;
  }

  test('order, progress and streak are kept on the phone', () async {
    final first = await open(seed: 1);
    final quiz = first.read(husnaQuizProvider.notifier);
    final q1 = first.read(husnaQuizProvider).question!;
    final order = first.read(husnaQuizProvider).progress!.order;
    expect(q1.position, 1);
    expect(q1.name.number, order.first);

    quiz.answer(q1.answer);
    quiz.answer((q1.answer + 1) % 4); // a second tap is ignored
    var s = first.read(husnaQuizProvider);
    expect(s.selected, q1.answer);
    expect(s.answeredRight, isTrue);
    expect((s.progress!.answered, s.progress!.correct, s.streak), (1, 1, 1));
    await Future<void>.delayed(Duration.zero);

    // Reopened later with another random source: same round, next question.
    final second = await open(seed: 99);
    s = second.read(husnaQuizProvider);
    expect(s.progress!.order, order);
    expect(s.question!.position, 2);
    expect(s.question!.name.number, order[1]);
    expect(s.selected, isNull);
    expect((s.progress!.answered, s.progress!.correct, s.streak), (1, 1, 1));
  });

  test(
    'a wrong answer counts as answered; Lanjut shows the next name',
    () async {
      final c = await open();
      final quiz = c.read(husnaQuizProvider.notifier);
      final q1 = c.read(husnaQuizProvider).question!;
      quiz.next(); // nothing happens before an answer
      expect(c.read(husnaQuizProvider).question!.position, 1);

      quiz.answer((q1.answer + 1) % q1.options.length);
      expect(c.read(husnaQuizProvider).answeredRight, isFalse);
      quiz.next();
      final s = c.read(husnaQuizProvider);
      expect(s.question!.position, 2);
      expect(s.selected, isNull);
      expect((s.progress!.answered, s.progress!.correct), (1, 0));
    },
  );

  test('the streak shown is broken after a missed day', () async {
    var c = await open();
    final q = c.read(husnaQuizProvider).question!;
    c.read(husnaQuizProvider.notifier).answer(q.answer);
    await Future<void>.delayed(Duration.zero);

    now = DateTime(2026, 10, 26, 7);
    c = await open();
    expect(c.read(husnaQuizProvider).streak, 1);

    now = DateTime(2026, 10, 28, 7);
    c = await open();
    expect(c.read(husnaQuizProvider).streak, 0);
  });

  test(
    'without the list and without a saved copy the quiz reports it',
    () async {
      api.offline = true;
      final c = await open();
      expect(c.read(husnaQuizProvider).error, isTrue);
      expect(c.read(husnaQuizProvider).loading, isFalse);
    },
  );
}
