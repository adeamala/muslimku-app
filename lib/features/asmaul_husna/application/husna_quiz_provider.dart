import 'dart:async';

import 'dart:convert';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muslimku/core/state/mounted_flag.dart';
import 'package:muslimku/features/asmaul_husna/application/asmaul_husna_provider.dart';
import 'package:muslimku/features/asmaul_husna/domain/husna_quiz_engine.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Shuffles the quiz; tests inject a seeded one.
final husnaQuizRandomProvider = Provider<Random>((ref) => Random());

/// Wall clock for the day streak; tests inject a fixed time.
final husnaQuizClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

class HusnaQuizState {
  const HusnaQuizState({
    this.progress,
    this.question,
    this.selected,
    this.streak = 0,
    this.error = false,
  });

  final QuizProgress? progress;
  final QuizQuestion? question;

  /// The option picked for [question], null until answered.
  final int? selected;

  /// Day streak as of today (0 once a day was missed).
  final int streak;

  /// The names could not be loaded (offline without a saved copy).
  final bool error;

  bool get loading => progress == null && !error;
  bool get answered => selected != null;
  bool get answeredRight => selected != null && selected == question?.answer;
}

/// The Asmaul Husna quiz, saved on the phone after every answer.
final husnaQuizProvider =
    NotifierProvider.autoDispose<HusnaQuizNotifier, HusnaQuizState>(
      HusnaQuizNotifier.new,
    );

class HusnaQuizNotifier extends AutoDisposeNotifier<HusnaQuizState> {
  static const prefsKey = 'husna_quiz_v1';

  late Random _random;
  late DateTime Function() _now;
  QuizEngine? _engine;

  /// Completes once the names and the saved progress are loaded.
  late Future<void> ready;

  @override
  HusnaQuizState build() {
    _random = ref.watch(husnaQuizRandomProvider);
    _now = ref.watch(husnaQuizClockProvider);
    _engine = null;
    ready = _load(
      ref.watch(husnaListProvider.future).then((c) => c.data),
      MountedFlag(ref),
    );
    return const HusnaQuizState();
  }

  Future<void> _load(Future<List<HusnaName>> names, MountedFlag alive) async {
    try {
      final list = await names;
      if (list.length < QuizEngine.optionCount) {
        throw StateError('not enough names');
      }
      final prefs = await SharedPreferences.getInstance();
      final engine = _engine = QuizEngine(list, random: _random);
      final saved = _decode(prefs.getString(prefsKey));
      var progress = saved == null ? engine.start() : engine.resume(saved);
      if (progress.finished) progress = engine.nextRound(progress);
      if (!alive.mounted) return;
      _show(progress, engine.question(progress));
      unawaited(_save(progress));
    } catch (_) {
      if (alive.mounted) state = const HusnaQuizState(error: true);
    }
  }

  /// Picks option [option] for the current question (once).
  void answer(int option) {
    final engine = _engine;
    final s = state;
    final question = s.question;
    if (engine == null || question == null || s.answered) return;
    final progress = engine.answer(
      s.progress!,
      correct: option == question.answer,
      today: _now(),
    );
    _show(progress, question, selected: option);
    _save(progress);
  }

  /// Shows the next name ("Lanjut"); after the last one a new round starts.
  void next() {
    final engine = _engine;
    if (engine == null || !state.answered) return;
    var progress = state.progress!;
    if (progress.finished) progress = engine.nextRound(progress);
    _show(progress, engine.question(progress));
    _save(progress);
  }

  void _show(QuizProgress progress, QuizQuestion question, {int? selected}) {
    state = HusnaQuizState(
      progress: progress,
      question: question,
      selected: selected,
      streak: progress.currentStreak(_now()),
    );
  }

  static QuizProgress? _decode(String? text) {
    if (text == null) return null;
    try {
      return QuizProgress.fromJson(jsonDecode(text) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> _save(QuizProgress progress) async {
    final text = jsonEncode(progress.toJson());
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefsKey, text);
  }
}
