import 'dart:async';

import 'package:muslimku/features/app_update/data/app_update_gateway.dart';

/// Scripted Play in-app updates. [downloadResult] finishes the background
/// download; complete it to move on.
class FakeAppUpdateGateway implements AppUpdateGateway {
  FakeAppUpdateGateway({this.update});

  AvailableUpdate? update;
  int checks = 0;
  int downloads = 0;
  int immediateRequests = 0;
  int installs = 0;
  bool immediateAccepted = false;
  Completer<UpdateDownloadResult> downloadResult = Completer();

  @override
  Future<AvailableUpdate?> check() async {
    checks++;
    return update;
  }

  @override
  Future<UpdateDownloadResult> download() {
    downloads++;
    return downloadResult.future;
  }

  @override
  Future<bool> updateNow() async {
    immediateRequests++;
    return immediateAccepted;
  }

  @override
  Future<void> install() async => installs++;
}
