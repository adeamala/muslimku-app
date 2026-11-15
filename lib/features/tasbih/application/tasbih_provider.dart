import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muslimku/core/state/mounted_flag.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The tasbih counter, saved on the phone.
final tasbihProvider = NotifierProvider<TasbihNotifier, TasbihState>(
  TasbihNotifier.new,
);

/// Dzikir of one phrase (e.g. a name from Asmaul Husna) shown instead of the
/// dzikir after salat.
class TasbihPreset {
  const TasbihPreset({
    required this.arabic,
    required this.latin,
    this.target = 33,
  });

  final String arabic;
  final String latin;
  final int target;

  @override
  bool operator ==(Object other) =>
      other is TasbihPreset &&
      other.arabic == arabic &&
      other.latin == latin &&
      other.target == target;

  @override
  int get hashCode => Object.hash(arabic, latin, target);
}

/// Counter for a [TasbihPreset]: starts at zero, is not saved and leaves the
/// regular tasbih counter alone.
final tasbihSessionProvider = NotifierProvider.autoDispose
    .family<TasbihSessionNotifier, TasbihState, TasbihPreset>(
      TasbihSessionNotifier.new,
    );

class TasbihState {
  const TasbihState({this.count = 0, this.target = 33});

  /// Taps since the last reset.
  final int count;

  /// 33, 99, or 0 for no target.
  final int target;

  /// Counter shown on screen: 1..target within the current round.
  int get roundCount {
    if (target == 0 || count == 0) return count;
    return (count - 1) % target + 1;
  }

  int get completedRounds => target == 0 ? 0 : count ~/ target;

  /// With a target of 33: 0 = Subhanallah, 1 = Alhamdulillah,
  /// 2 = Allahu Akbar (dzikir after salat). Null for other targets.
  int? get dzikirIndex {
    if (target != 33) return null;
    if (count == 0) return 0;
    return ((count - 1) ~/ 33) % 3;
  }

  TasbihState copyWith({int? count, int? target}) =>
      TasbihState(count: count ?? this.count, target: target ?? this.target);
}

/// What every tasbih counter can do; [TasbihNotifier] also saves it.
mixin TasbihCounter {
  TasbihState get state;
  set state(TasbihState value);

  /// Called after every change.
  void onChanged() {}

  /// Adds one. Returns true when this tap completed a round.
  bool increment() {
    final next = state.count + 1;
    state = state.copyWith(count: next);
    onChanged();
    return state.target > 0 && next % state.target == 0;
  }

  void setTarget(int target) {
    state = TasbihState(count: 0, target: target);
    onChanged();
  }

  void reset() {
    state = state.copyWith(count: 0);
    onChanged();
  }
}

class TasbihNotifier extends Notifier<TasbihState> with TasbihCounter {
  static const countKey = 'tasbih_count';
  static const targetKey = 'tasbih_target';
  static const targets = [33, 99, 0];

  /// Completes once the saved counter has been restored.
  late Future<void> ready;
  bool _touched = false;

  @override
  TasbihState build() {
    _touched = false;
    ready = _load(MountedFlag(ref));
    return const TasbihState();
  }

  Future<void> _load(MountedFlag alive) async {
    final prefs = await SharedPreferences.getInstance();
    // The user already tapped; keep that.
    if (_touched || !alive.mounted) return;
    final target = prefs.getInt(targetKey) ?? 33;
    state = TasbihState(
      count: prefs.getInt(countKey) ?? 0,
      target: targets.contains(target) ? target : 33,
    );
  }

  @override
  void onChanged() {
    _touched = true;
    unawaited(_save());
  }

  Future<void> _save() async {
    // Read the state now: the provider may be disposed after the await.
    final count = state.count;
    final target = state.target;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(countKey, count);
    await prefs.setInt(targetKey, target);
  }
}

/// A counter for one [TasbihPreset] that is not saved.
class TasbihSessionNotifier
    extends AutoDisposeFamilyNotifier<TasbihState, TasbihPreset>
    with TasbihCounter {
  @override
  TasbihState build(TasbihPreset preset) => TasbihState(target: preset.target);
}
