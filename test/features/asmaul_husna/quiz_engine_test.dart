import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:muslimku/features/asmaul_husna/application/asmaul_husna_provider.dart';
import 'package:muslimku/features/asmaul_husna/domain/husna_quiz_engine.dart';

import '../../support/fake_husna_doa_api.dart';

final _names = [for (final h in FakeHusnaDoaApi.husna) HusnaName.fromJson(h)];

String _norm(String s) => s.trim().toLowerCase();

void main() {
  group('options', () {
    test('four distinct meanings, the right one exactly once', () {
      for (var seed = 0; seed < 20; seed++) {
        final engine = QuizEngine(_names, random: Random(seed));
        var progress = engine.start();
        while (!progress.finished) {
          final q = engine.question(progress);
          expect(q.options, hasLength(4));
          expect(q.options.map(_norm).toSet(), hasLength(4));
          expect(q.options[q.answer], q.name.meaning);
          expect(
            q.options.where((o) => _norm(o) == _norm(q.name.meaning)),
            hasLength(1),
            reason: 'names 1 and 83 share "Yang Maha Pengasih"',
          );
          progress = engine.answer(
            progress,
            correct: true,
            today: DateTime(2026, 10, 25),
          );
        }
      }
    });

    test('the right answer is not always in the same place', () {
      final engine = QuizEngine(_names, random: Random(3));
      var progress = engine.start();
      final places = <int>{};
      while (!progress.finished) {
        places.add(engine.question(progress).answer);
        progress = engine.answer(
          progress,
          correct: false,
          today: DateTime(2026),
        );
      }
      expect(places.length, greaterThan(1));
    });
  });

  group('order', () {
    test('every name once, shuffled by the injected random', () {
      final a = QuizEngine(_names, random: Random(1)).start().order;
      final b = QuizEngine(_names, random: Random(2)).start().order;
      expect(a.toSet(), _names.map((n) => n.number).toSet());
      expect(a, hasLength(_names.length));
      expect(a, isNot(equals(b)));
      expect(QuizEngine(_names, random: Random(1)).start().order, a);
    });

    test('survives a save and restore', () {
      final engine = QuizEngine(_names, random: Random(5));
      var progress = engine.start();
      progress = engine.answer(
        progress,
        correct: true,
        today: DateTime(2026, 10, 25),
      );
      final restored = engine.resume(QuizProgress.fromJson(progress.toJson()));
      expect(restored.order, progress.order);
      expect(restored.index, 1);
      expect(restored.answered, 1);
      expect(restored.correct, 1);
      expect(engine.question(restored).name.number, progress.order[1]);
    });

    test('a saved order that no longer fits the names starts a new round', () {
      final engine = QuizEngine(_names, random: Random(5));
      final stale = QuizProgress(
        order: const [1, 2, 3],
        index: 2,
        answered: 2,
        correct: 2,
        streak: 4,
        lastDay: DateTime(2026, 10, 24),
      );
      final resumed = engine.resume(stale);
      expect(resumed.order, hasLength(_names.length));
      expect(resumed.index, 0);
      expect(resumed.answered, 0);
      expect(resumed.streak, 4, reason: 'the day streak is kept');
    });
  });

  test('scoring counts answers and right answers and moves on', () {
    final engine = QuizEngine(_names, random: Random(9));
    var p = engine.start();
    final day = DateTime(2026, 10, 25);
    p = engine.answer(p, correct: true, today: day);
    p = engine.answer(p, correct: false, today: day);
    p = engine.answer(p, correct: true, today: day);
    expect((p.index, p.answered, p.correct), (3, 3, 2));
  });

  group('day streak', () {
    test(
      'grows on consecutive days, once per day, and restarts after a gap',
      () {
        final engine = QuizEngine(_names, random: Random(1));
        var p = engine.start();
        expect(p.currentStreak(DateTime(2026, 10, 20)), 0);

        p = engine.answer(
          p,
          correct: true,
          today: DateTime(2026, 10, 20, 23, 50),
        );
        expect(p.streak, 1);
        p = engine.answer(
          p,
          correct: false,
          today: DateTime(2026, 10, 20, 23, 59),
        );
        expect(p.streak, 1, reason: 'one answer per day is enough');
        p = engine.answer(
          p,
          correct: true,
          today: DateTime(2026, 10, 21, 0, 5),
        );
        expect(p.streak, 2);
        p = engine.answer(p, correct: true, today: DateTime(2026, 10, 22, 7));
        expect(p.streak, 3);

        expect(
          p.currentStreak(DateTime(2026, 10, 23, 21)),
          3,
          reason: 'still today',
        );
        expect(
          p.currentStreak(DateTime(2026, 10, 24, 6)),
          0,
          reason: 'a day was missed',
        );

        p = engine.answer(p, correct: true, today: DateTime(2026, 10, 24, 6));
        expect(p.streak, 1);
        expect(p.lastDay, DateTime(2026, 10, 24));
      },
    );

    test('counts calendar days across a month end', () {
      final engine = QuizEngine(_names, random: Random(1));
      var p = engine.start();
      p = engine.answer(p, correct: true, today: DateTime(2026, 10, 31, 22));
      p = engine.answer(p, correct: true, today: DateTime(2026, 11, 1, 1));
      expect(p.streak, 2);
    });
  });

  test('after the last name a new round starts and the streak stays', () {
    final engine = QuizEngine(_names, random: Random(2));
    var p = engine.start();
    for (var i = 0; i < _names.length; i++) {
      p = engine.answer(p, correct: i.isEven, today: DateTime(2026, 10, 25));
    }
    expect(p.finished, isTrue);
    expect(p.correct, 7);
    final next = engine.nextRound(p);
    expect((next.index, next.answered, next.correct), (0, 0, 0));
    expect(next.order.toSet(), p.order.toSet());
    expect(next.streak, p.streak);
    expect(next.lastDay, p.lastDay);
  });
}
