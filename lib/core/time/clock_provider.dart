import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Reads the current time. Code that needs "now" once (not a ticking clock)
/// reads this instead of calling `DateTime.now()`, so tests can fix the date.
final nowProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Wall clock for the home countdown. Ticks every 15 s while someone listens;
/// tests override it with a fixed time.
final clockProvider = StreamProvider.autoDispose<DateTime>((ref) async* {
  final now = ref.watch(nowProvider);
  yield now();
  yield* Stream.periodic(const Duration(seconds: 15), (_) => now());
});
