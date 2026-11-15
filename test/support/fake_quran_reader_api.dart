import 'dart:async';

import 'package:muslimku/features/quran/application/quran_audio_provider.dart';

/// Stand-in for the murottal audio player: records what was played and lets
/// a test finish the current ayah ([complete]) or break the connection.
class FakeMurottalPlayer implements MurottalPlayer {
  FakeMurottalPlayer({this.failing = const {}});

  /// URLs that fail to load (as without internet).
  Set<String> failing;
  final List<String> played = [];
  final List<String> calls = [];
  bool disposed = false;

  final _completed = StreamController<void>.broadcast();
  final _errors = StreamController<Object>.broadcast();
  final _position = StreamController<Duration>.broadcast();
  final _duration = StreamController<Duration?>.broadcast();

  String? get current => played.isEmpty ? null : played.last;

  /// The current ayah played to the end.
  void complete() => _completed.add(null);

  /// The connection dropped while playing.
  void fail([Object error = 'offline']) => _errors.add(error);

  void tick(Duration position, Duration duration) {
    _duration.add(duration);
    _position.add(position);
  }

  @override
  Future<void> play(String url) async {
    calls.add('play');
    if (failing.contains(url) || failing.contains('*')) {
      throw Exception('SocketException: offline');
    }
    played.add(url);
  }

  @override
  Future<void> pause() async => calls.add('pause');

  @override
  Future<void> resume() async => calls.add('resume');

  @override
  Future<void> stop() async => calls.add('stop');

  @override
  Stream<void> get completed => _completed.stream;

  @override
  Stream<Object> get errors => _errors.stream;

  @override
  Stream<Duration> get position => _position.stream;

  @override
  Stream<Duration?> get duration => _duration.stream;

  @override
  Future<void> dispose() async {
    disposed = true;
    calls.add('dispose');
  }
}
