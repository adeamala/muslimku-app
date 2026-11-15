import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:muslimku/core/state/mounted_flag.dart';
import 'package:muslimku/features/quran/data/murottal_store.dart';
import 'package:muslimku/features/quran/domain/quran_models.dart';
import 'package:muslimku/features/quran/domain/reciters.dart';
import 'package:muslimku/features/reading/application/reading_settings_provider.dart';

/// Plays one audio file at a time. [JustAudioMurottalPlayer] on phones; tests
/// pass a fake through [murottalPlayerFactoryProvider].
abstract class MurottalPlayer {
  /// Loads [url] and starts playing it. Throws when it cannot be loaded.
  Future<void> play(String url);
  Future<void> pause();
  Future<void> resume();
  Future<void> stop();

  /// Fires when the current file has played to the end.
  Stream<void> get completed;

  /// Errors after loading, e.g. when the connection drops while playing.
  Stream<Object> get errors;
  Stream<Duration> get position;
  Stream<Duration?> get duration;
  Future<void> dispose();
}

/// [MurottalPlayer] on just_audio. Uses only the API shared by just_audio
/// 0.9.46 and 0.10 (`setUrl`, `play`, `pause`, `stop`, the state streams).
class JustAudioMurottalPlayer implements MurottalPlayer {
  JustAudioMurottalPlayer() : _player = AudioPlayer() {
    _events = _player.playbackEventStream.listen(
      (_) {},
      onError: (Object error, StackTrace _) => _report(error),
    );
  }

  final AudioPlayer _player;
  final _errors = StreamController<Object>.broadcast();
  late final StreamSubscription<PlaybackEvent> _events;

  void _report(Object error) {
    if (!_errors.isClosed) _errors.add(error);
  }

  @override
  Future<void> play(String url) async {
    await _player.setUrl(url);
    // play() completes only when playback pauses or ends.
    unawaited(_player.play().catchError(_report));
  }

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> resume() async {
    unawaited(_player.play().catchError(_report));
  }

  @override
  Future<void> stop() => _player.stop();

  @override
  Stream<void> get completed => _player.processingStateStream
      .where((s) => s == ProcessingState.completed)
      .map((_) {});

  @override
  Stream<Object> get errors => _errors.stream;

  @override
  Stream<Duration> get position => _player.positionStream;

  @override
  Stream<Duration?> get duration => _player.durationStream;

  @override
  Future<void> dispose() async {
    await _events.cancel();
    await _errors.close();
    await _player.dispose();
  }
}

/// Position in the ayah being played, for the progress line of the player.
class MurottalProgress {
  const MurottalProgress(this.position, this.duration);

  static const zero = MurottalProgress(Duration.zero, null);

  final Duration position;
  final Duration? duration;

  /// 0–1 through the current ayah.
  double get fraction {
    final total = duration?.inMilliseconds ?? 0;
    if (total <= 0) return 0;
    return (position.inMilliseconds / total).clamp(0.0, 1.0);
  }
}

/// What the murottal player is doing.
class MurottalState {
  const MurottalState({
    this.surah,
    this.surahName = '',
    this.arabicName = '',
    this.ayah,
    this.lastAyah = 0,
    this.playing = false,
    this.loading = false,
    this.message,
    this.reciter = '',
  });

  /// Surah being recited, null when stopped.
  final int? surah;
  final String surahName;
  final String arabicName;

  /// Ayah being played or paused, null when stopped.
  final int? ayah;
  final int lastAyah;
  final bool playing;

  /// The audio of [ayah] is still downloading.
  final bool loading;

  /// One-off message for a snackbar, e.g. [QuranAudioController.offlineMessage].
  final String? message;

  /// Name of the qari of the ayah being played (shown in the mini player).
  final String reciter;

  /// The mini player is shown (playing or paused).
  bool get active => surah != null && ayah != null;

  bool isCurrent(int surahNumber, int ayahNumber) =>
      active && surah == surahNumber && ayah == ayahNumber;

  MurottalState copyWith({
    int? ayah,
    bool? playing,
    bool? loading,
    String? message,
    String? reciter,
  }) => MurottalState(
    surah: surah,
    surahName: surahName,
    arabicName: arabicName,
    ayah: ayah ?? this.ayah,
    lastAyah: lastAyah,
    playing: playing ?? this.playing,
    loading: loading ?? this.loading,
    message: message ?? this.message,
    reciter: reciter ?? this.reciter,
  );
}

/// Murottal ayah by ayah, continuing with the next ayah until the end of the
/// surah. The qari comes from [reciter] at every ayah, so a change in
/// Pengaturan takes effect from the next ayah.
class QuranAudioController extends AutoDisposeNotifier<MurottalState> {
  static const offlineMessage = 'Audio butuh internet';

  late MurottalPlayer Function() _createPlayer;
  late MountedFlag _alive;
  MurottalPlayer? _player;
  final List<StreamSubscription<Object?>> _subs = [];
  List<Ayah> _queue = const [];

  /// Bumped on every new request, so late results of older ones are ignored.
  int _request = 0;

  /// Position in the current ayah (kept out of [state] so the reader does not
  /// rebuild several times a second).
  late ValueNotifier<MurottalProgress> progress;

  @override
  MurottalState build() {
    _createPlayer = ref.watch(murottalPlayerFactoryProvider);
    _alive = MountedFlag(ref);
    _queue = const [];
    progress = ValueNotifier(MurottalProgress.zero);
    ref.onDispose(_release);
    return const MurottalState();
  }

  /// The qari is read at every ayah, so a change in Pengaturan takes effect
  /// from the next ayah.
  Reciter _reciter() => ref.read(readingSettingsProvider).reciter;

  /// `file://` URL of the ayah saved on the phone, if any (Murottal offline).
  Future<String?> _localUrl(Reciter reciter, int ayahId) =>
      ref.read(murottalStoreProvider).url(reciter, ayahId);

  MurottalPlayer _ensurePlayer() {
    final existing = _player;
    if (existing != null) return existing;
    final player = _player = _createPlayer();
    _subs
      ..add(player.completed.listen((_) => _onCompleted()))
      ..add(player.errors.listen((_) => _fail()))
      ..add(
        player.duration.listen(
          (d) => progress.value = MurottalProgress(progress.value.position, d),
        ),
      )
      ..add(
        player.position.listen(
          (p) => progress.value = MurottalProgress(p, progress.value.duration),
        ),
      );
    return player;
  }

  /// Starts [surah] at ayah [from].
  Future<void> playSurah(Surah surah, List<Ayah> ayat, {int from = 1}) {
    if (ayat.isEmpty) return stop();
    _queue = [...ayat]..sort((a, b) => a.number.compareTo(b.number));
    state = MurottalState(
      surah: surah.number,
      surahName: surah.name,
      arabicName: surah.arabicName,
      lastAyah: _queue.last.number,
    );
    return playAyah(from);
  }

  /// Plays ayah [number] of the surah started with [playSurah].
  Future<void> playAyah(int number) async {
    final ayah = _queue.where((a) => a.number == number).firstOrNull;
    if (ayah == null || state.surah == null) return stop();
    final request = ++_request;
    progress.value = MurottalProgress.zero;
    final reciter = _reciter();
    state = state.copyWith(
      ayah: number,
      playing: true,
      loading: true,
      reciter: reciter.label,
    );
    try {
      final player = _ensurePlayer();
      // A saved file wins; a slow disk never delays the stream.
      final local = await Future.any<String?>([
        _localUrl(reciter, ayah.id),
        Future.delayed(const Duration(milliseconds: 300), () => null),
      ]);
      if (!_alive.mounted || request != _request) return;
      await player.play(local ?? ayah.audioUrlFor(reciter));
      if (!_alive.mounted || request != _request) return;
      state = state.copyWith(loading: false);
    } catch (_) {
      if (!_alive.mounted || request != _request) return;
      _fail();
    }
  }

  Future<void> pause() async {
    if (!state.active || !state.playing) return;
    state = state.copyWith(playing: false);
    await _player?.pause();
  }

  Future<void> resume() async {
    if (!state.active || state.playing) return;
    state = state.copyWith(playing: true);
    await _player?.resume();
  }

  Future<void> toggle() => state.playing ? pause() : resume();

  Future<void> next() async {
    final ayah = state.ayah;
    if (!state.active || ayah == null) return;
    if (ayah >= state.lastAyah) return stop();
    return playAyah(ayah + 1);
  }

  /// The ayah before; restarts the first ayah.
  Future<void> previous() async {
    final ayah = state.ayah;
    if (!state.active || ayah == null) return;
    return playAyah(math.max(_queue.first.number, ayah - 1));
  }

  Future<void> stop() async {
    if (!_alive.mounted) return;
    _request++;
    progress.value = MurottalProgress.zero;
    state = const MurottalState();
    await _player?.stop();
  }

  /// Silences the player without notifying listeners (safe while widgets are
  /// being disposed); call [stop] afterwards to reset the state.
  void release() {
    _request++;
    final player = _player;
    if (player != null) unawaited(player.stop());
  }

  void clearMessage() {
    if (!_alive.mounted || state.message == null) return;
    state = MurottalState(
      surah: state.surah,
      surahName: state.surahName,
      arabicName: state.arabicName,
      ayah: state.ayah,
      lastAyah: state.lastAyah,
      playing: state.playing,
      loading: state.loading,
    );
  }

  void _onCompleted() {
    final idle = !state.active || !state.playing || state.loading;
    if (!_alive.mounted || idle) return;
    unawaited(next());
  }

  void _fail() {
    if (!_alive.mounted || !state.active) return;
    _request++;
    progress.value = MurottalProgress.zero;
    state = const MurottalState(message: offlineMessage);
    _player?.stop();
  }

  void _release() {
    _request++;
    for (final sub in _subs) {
      unawaited(sub.cancel());
    }
    _subs.clear();
    _player?.dispose();
    _player = null;
    progress.dispose();
  }
}

/// Creates the audio player; tests override it with a fake.
final murottalPlayerFactoryProvider = Provider<MurottalPlayer Function()>(
  (ref) => JustAudioMurottalPlayer.new,
);

/// The murottal of the open reader. Disposed (and silenced) with the reader.
final quranAudioProvider =
    NotifierProvider.autoDispose<QuranAudioController, MurottalState>(
      QuranAudioController.new,
    );
