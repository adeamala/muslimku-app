import 'dart:math';

import 'package:muslimku/features/asmaul_husna/application/asmaul_husna_provider.dart';

/// Saved state of the Asmaul Husna quiz (one round = every name once).
class QuizProgress {
  const QuizProgress({
    required this.order,
    this.index = 0,
    this.answered = 0,
    this.correct = 0,
    this.streak = 0,
    this.lastDay,
  });

  factory QuizProgress.fromJson(Map<String, dynamic> json) => QuizProgress(
    order: [for (final n in (json['order'] as List? ?? const [])) _asInt(n)],
    index: _asInt(json['index']),
    answered: _asInt(json['answered']),
    correct: _asInt(json['correct']),
    streak: _asInt(json['streak']),
    lastDay: DateTime.tryParse('${json['lastDay'] ?? ''}'),
  );

  /// Name numbers in the order they are asked.
  final List<int> order;

  /// Position of the next question to ask in [order].
  final int index;

  /// Answers and right answers in this round.
  final int answered;
  final int correct;

  /// Consecutive local days with at least one answer, up to [lastDay].
  final int streak;
  final DateTime? lastDay;

  bool get finished => index >= order.length;

  /// The streak as of [today]: it is broken once a whole day was missed.
  int currentStreak(DateTime today) {
    final last = lastDay;
    if (last == null) return 0;
    return _daysBetween(last, today) <= 1 ? streak : 0;
  }

  QuizProgress copyWith({
    List<int>? order,
    int? index,
    int? answered,
    int? correct,
    int? streak,
    DateTime? lastDay,
  }) => QuizProgress(
    order: order ?? this.order,
    index: index ?? this.index,
    answered: answered ?? this.answered,
    correct: correct ?? this.correct,
    streak: streak ?? this.streak,
    lastDay: lastDay ?? this.lastDay,
  );

  Map<String, Object?> toJson() => {
    'order': order,
    'index': index,
    'answered': answered,
    'correct': correct,
    'streak': streak,
    'lastDay': lastDay == null ? null : _isoDay(lastDay!),
  };
}

/// One question: what does [name] mean?
class QuizQuestion {
  const QuizQuestion({
    required this.name,
    required this.options,
    required this.answer,
    required this.position,
    required this.total,
  });

  final HusnaName name;

  /// Four meanings, all different.
  final List<String> options;

  /// Index of the right meaning in [options].
  final int answer;

  /// 1-based position in the round, out of [total].
  final int position;
  final int total;
}

/// Offline quiz logic: shuffled order, answer options and scoring.
/// [random] is injected so tests are repeatable.
class QuizEngine {
  QuizEngine(List<HusnaName> names, {Random? random})
    : names = [...names]..sort((a, b) => a.number.compareTo(b.number)),
      _random = random ?? Random();

  static const optionCount = 4;

  final List<HusnaName> names;
  final Random _random;

  late final Map<int, HusnaName> _byNumber = {
    for (final n in names) n.number: n,
  };

  List<int> _shuffledOrder() =>
      [for (final n in names) n.number]..shuffle(_random);

  QuizProgress start() => QuizProgress(order: _shuffledOrder());

  /// A new round after the last name; the day streak carries over.
  QuizProgress nextRound(QuizProgress progress) => QuizProgress(
    order: _shuffledOrder(),
    streak: progress.streak,
    lastDay: progress.lastDay,
  );

  /// Continues a saved round, or starts a new one when the names changed.
  QuizProgress resume(QuizProgress saved) {
    final fits =
        saved.order.length == names.length &&
        saved.order.toSet().length == names.length &&
        saved.order.every(_byNumber.containsKey) &&
        saved.index >= 0 &&
        saved.index <= saved.order.length;
    return fits ? saved : nextRound(saved);
  }

  QuizQuestion question(QuizProgress progress) {
    final name = _byNumber[progress.order[progress.index]]!;
    final answerKey = _key(name.meaning);
    final seen = {answerKey};
    final distractors = <String>[];
    for (final other in [...names]..shuffle(_random)) {
      if (distractors.length == optionCount - 1) break;
      if (seen.add(_key(other.meaning))) distractors.add(other.meaning);
    }
    final answer = _random.nextInt(distractors.length + 1);
    return QuizQuestion(
      name: name,
      options: [...distractors]..insert(answer, name.meaning),
      answer: answer,
      position: progress.index + 1,
      total: progress.order.length,
    );
  }

  /// Records an answer to the current question and moves to the next one.
  QuizProgress answer(
    QuizProgress progress, {
    required bool correct,
    required DateTime today,
  }) {
    final last = progress.lastDay;
    final gap = last == null ? null : _daysBetween(last, today);
    final streak = switch (gap) {
      0 => progress.streak,
      1 => progress.streak + 1,
      _ => 1,
    };
    return progress.copyWith(
      index: progress.index + 1,
      answered: progress.answered + 1,
      correct: progress.correct + (correct ? 1 : 0),
      streak: streak,
      lastDay: DateTime(today.year, today.month, today.day),
    );
  }

  static String _key(String meaning) => meaning.trim().toLowerCase();
}

/// Calendar days from [a] to [b] in local dates (DST-safe).
int _daysBetween(DateTime a, DateTime b) => DateTime.utc(
  b.year,
  b.month,
  b.day,
).difference(DateTime.utc(a.year, a.month, a.day)).inDays;

String _isoDay(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

int _asInt(Object? value) =>
    value is int ? value : int.tryParse('${value ?? ''}') ?? 0;
