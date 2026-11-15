import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muslimku/core/state/mounted_flag.dart';
import 'package:muslimku/core/time/clock_provider.dart';
import 'package:muslimku/features/app_update/data/app_update_gateway.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum UpdatePhase {
  /// Nothing to show.
  none,

  /// A newer version is on Play; the sheet offers it.
  available,

  /// Downloading in the background; the banner shows progress.
  downloading,

  /// Downloaded; the banner offers to install.
  ready,
}

class AppUpdateState {
  const AppUpdateState({
    this.phase = UpdatePhase.none,
    this.update,
    this.prompt = false,
    this.bannerHidden = false,
    this.failed = false,
  });

  final UpdatePhase phase;
  final AvailableUpdate? update;

  /// The update sheet should open now. The screen that shows it calls
  /// [AppUpdateNotifier.promptShown], so it opens once per check.
  final bool prompt;

  /// The user closed the download/install banner for this session.
  final bool bannerHidden;

  /// The last download failed; the screen shows a short message once and
  /// calls [AppUpdateNotifier.failureShown].
  final bool failed;

  bool get showBanner =>
      !bannerHidden &&
      (phase == UpdatePhase.downloading || phase == UpdatePhase.ready);

  AppUpdateState copyWith({
    UpdatePhase? phase,
    AvailableUpdate? update,
    bool? prompt,
    bool? bannerHidden,
    bool? failed,
  }) => AppUpdateState(
    phase: phase ?? this.phase,
    update: update ?? this.update,
    prompt: prompt ?? this.prompt,
    bannerHidden: bannerHidden ?? this.bannerHidden,
    failed: failed ?? this.failed,
  );
}

/// Offers a newer Play version when the app opens or comes back to the
/// front, downloads it in the background and installs it on request.
///
/// "Nanti saja" hides the offer for [snooze] (one day for an important
/// update), per version, so people are not asked on every launch.
class AppUpdateNotifier extends Notifier<AppUpdateState> {
  late AppUpdateGateway _gateway;
  late DateTime Function() _now;
  late MountedFlag _alive;

  @override
  AppUpdateState build() {
    _gateway = ref.read(appUpdateGatewayProvider);
    _now = ref.read(nowProvider);
    _alive = MountedFlag(ref);
    _lastCheck = null;
    _checking = false;
    return const AppUpdateState();
  }

  static const snooze = Duration(days: 3);
  static const importantSnooze = Duration(days: 1);

  /// Coming back to the app re-checks at most this often (a download in
  /// progress is always re-checked, to notice when it has finished).
  static const resumeInterval = Duration(hours: 1);

  static String snoozeKey(int versionCode) => 'update_snoozed_$versionCode';

  DateTime? _lastCheck;
  bool _checking = false;

  /// [onResume]: called when the app returns to the front.
  Future<void> check({bool onResume = false}) async {
    if (_checking) return;
    final last = _lastCheck;
    if (onResume &&
        state.phase != UpdatePhase.downloading &&
        last != null &&
        _now().difference(last) < resumeInterval) {
      return;
    }
    _checking = true;
    try {
      _lastCheck = _now();
      final update = await _gateway.check();
      if (!_alive.mounted) return;
      if (update == null) {
        // Keep a download that is still running in this session.
        if (state.phase != UpdatePhase.downloading) {
          state = const AppUpdateState();
        }
        return;
      }
      switch (update.stage) {
        case UpdateStage.downloaded:
          state = state.copyWith(
            phase: UpdatePhase.ready,
            update: update,
            prompt: false,
          );
        case UpdateStage.downloading:
          state = state.copyWith(
            phase: UpdatePhase.downloading,
            update: update,
            prompt: false,
          );
        case UpdateStage.available:
          if (state.phase == UpdatePhase.downloading) return;
          final snoozed = await _isSnoozed(update);
          if (!_alive.mounted) return;
          state = AppUpdateState(
            phase: UpdatePhase.available,
            update: update,
            prompt: !snoozed,
          );
      }
    } finally {
      _checking = false;
    }
  }

  void promptShown() {
    if (state.prompt) state = state.copyWith(prompt: false);
  }

  void failureShown() {
    if (state.failed) state = state.copyWith(failed: false);
  }

  /// "Perbarui sekarang".
  Future<void> accept() async {
    final update = state.update;
    if (update == null) return;
    if (!update.flexibleAllowed) {
      final went = await _gateway.updateNow();
      if (!went) await later();
      return;
    }
    state = state.copyWith(
      phase: UpdatePhase.downloading,
      prompt: false,
      bannerHidden: false,
    );
    final result = await _gateway.download();
    if (!_alive.mounted) return;
    switch (result) {
      case UpdateDownloadResult.downloaded:
        state = state.copyWith(phase: UpdatePhase.ready, bannerHidden: false);
      case UpdateDownloadResult.declined:
        state = state.copyWith(phase: UpdatePhase.available);
        await later();
      case UpdateDownloadResult.failed:
        state = state.copyWith(phase: UpdatePhase.available, failed: true);
    }
  }

  /// "Nanti saja": quiet for this version until the snooze runs out.
  Future<void> later() async {
    final update = state.update;
    state = state.copyWith(prompt: false);
    if (update == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      snoozeKey(update.versionCode),
      _now().millisecondsSinceEpoch,
    );
  }

  /// "Pasang": Android restarts the app with the new version.
  Future<void> install() => _gateway.install();

  void hideBanner() => state = state.copyWith(bannerHidden: true);

  Future<bool> _isSnoozed(AvailableUpdate update) async {
    final prefs = await SharedPreferences.getInstance();
    final at = prefs.getInt(snoozeKey(update.versionCode));
    if (at == null) return false;
    final since = _now().difference(DateTime.fromMillisecondsSinceEpoch(at));
    return since < (update.important ? importantSnooze : snooze);
  }
}

final appUpdateProvider = NotifierProvider<AppUpdateNotifier, AppUpdateState>(
  AppUpdateNotifier.new,
);
