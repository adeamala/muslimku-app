import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_update/in_app_update.dart';

import 'package:muslimku/core/storage/local_store.dart'
    show runningInFlutterTest;

/// Where a newer version stands on this phone.
enum UpdateStage {
  /// On Play, not downloaded yet.
  available,

  /// Play is downloading it in the background.
  downloading,

  /// Downloaded; installing restarts the app.
  downloaded,
}

/// A newer version of the app that Google Play offers.
class AvailableUpdate {
  const AvailableUpdate({
    required this.versionCode,
    this.stage = UpdateStage.available,
    this.flexibleAllowed = true,
    this.immediateAllowed = false,
    this.priority = 0,
  });

  /// Play's version code of the newer version (0 when Play did not say).
  final int versionCode;
  final UpdateStage stage;

  /// Whether Play may download it in the background while the app is used.
  final bool flexibleAllowed;

  /// Whether Play may show its own full-screen update instead.
  final bool immediateAllowed;

  /// 0–5, set per release through the Play Developer API. 4 and up are
  /// treated as important: "Nanti" does not hide them for days.
  final int priority;

  bool get important => priority >= 4;
}

enum UpdateDownloadResult { downloaded, declined, failed }

/// Google Play's in-app updates. Every method swallows errors: a phone where
/// the app did not come from Play (debug builds, sideloaded APKs) just never
/// sees an update.
abstract class AppUpdateGateway {
  /// The newer version on Play, or null when there is none or Play cannot
  /// tell (offline, not installed from Play).
  Future<AvailableUpdate?> check();

  /// Asks the user (Play's own dialog) and downloads in the background.
  /// Completes once the download finished, was declined or failed.
  Future<UpdateDownloadResult> download();

  /// Play's full-screen update, for when a background download is not
  /// allowed. True when the user went ahead.
  Future<bool> updateNow();

  /// Installs a downloaded update. Android closes and reopens the app.
  Future<void> install();
}

class PlayAppUpdateGateway implements AppUpdateGateway {
  const PlayAppUpdateGateway();

  @override
  Future<AvailableUpdate?> check() async {
    try {
      final info = await InAppUpdate.checkForUpdate();
      final code = info.availableVersionCode ?? 0;
      final priority = info.updatePriority;
      switch (info.installStatus) {
        case InstallStatus.downloaded:
          return AvailableUpdate(
            versionCode: code,
            stage: UpdateStage.downloaded,
            priority: priority,
          );
        case InstallStatus.pending:
        case InstallStatus.downloading:
          return AvailableUpdate(
            versionCode: code,
            stage: UpdateStage.downloading,
            priority: priority,
          );
        default:
          break;
      }
      if (info.updateAvailability != UpdateAvailability.updateAvailable) {
        return null;
      }
      if (!info.flexibleUpdateAllowed && !info.immediateUpdateAllowed) {
        return null;
      }
      return AvailableUpdate(
        versionCode: code,
        flexibleAllowed: info.flexibleUpdateAllowed,
        immediateAllowed: info.immediateUpdateAllowed,
        priority: priority,
      );
    } catch (e) {
      debugPrint('In-app update check skipped: $e');
      return null;
    }
  }

  @override
  Future<UpdateDownloadResult> download() async {
    try {
      // Completes when Play reports the download as finished.
      final result = await InAppUpdate.startFlexibleUpdate();
      return switch (result) {
        AppUpdateResult.success => UpdateDownloadResult.downloaded,
        AppUpdateResult.userDeniedUpdate => UpdateDownloadResult.declined,
        AppUpdateResult.inAppUpdateFailed => UpdateDownloadResult.failed,
      };
    } catch (e) {
      debugPrint('In-app update download failed: $e');
      return UpdateDownloadResult.failed;
    }
  }

  @override
  Future<bool> updateNow() async {
    try {
      final result = await InAppUpdate.performImmediateUpdate();
      return result == AppUpdateResult.success;
    } catch (e) {
      debugPrint('In-app immediate update failed: $e');
      return false;
    }
  }

  @override
  Future<void> install() async {
    // Play restarts the app, so this future usually never completes.
    unawaited(
      InAppUpdate.completeFlexibleUpdate().catchError((Object e) {
        debugPrint('In-app update install failed: $e');
      }),
    );
  }
}

/// No updates: web, iOS (the App Store updates apps itself) and tests.
class NoAppUpdateGateway implements AppUpdateGateway {
  const NoAppUpdateGateway();

  @override
  Future<AvailableUpdate?> check() async => null;

  @override
  Future<UpdateDownloadResult> download() async => UpdateDownloadResult.failed;

  @override
  Future<bool> updateNow() async => false;

  @override
  Future<void> install() async {}
}

/// Pretends Play has a newer version, to look at the update screens on any
/// build: `flutter run --dart-define=MUSLIMKU_DEMO_UPDATE=true`.
class DemoAppUpdateGateway implements AppUpdateGateway {
  DemoAppUpdateGateway({this.downloadTime = const Duration(seconds: 8)});

  final Duration downloadTime;
  bool _installed = false;

  @override
  Future<AvailableUpdate?> check() async =>
      _installed ? null : const AvailableUpdate(versionCode: 999);

  @override
  Future<UpdateDownloadResult> download() async {
    await Future<void>.delayed(downloadTime);
    return UpdateDownloadResult.downloaded;
  }

  @override
  Future<bool> updateNow() async => true;

  @override
  Future<void> install() async => _installed = true;
}

const _demoUpdate = bool.fromEnvironment('MUSLIMKU_DEMO_UPDATE');

final appUpdateGatewayProvider = Provider<AppUpdateGateway>((ref) {
  if (_demoUpdate) return DemoAppUpdateGateway();
  if (kIsWeb || runningInFlutterTest || !Platform.isAndroid) {
    return const NoAppUpdateGateway();
  }
  return const PlayAppUpdateGateway();
});
