import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muslimku/core/time/clock_provider.dart';
import 'package:muslimku/features/app_update/application/app_update_provider.dart';
import 'package:muslimku/features/app_update/data/app_update_gateway.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_app_update_gateway.dart';

void main() {
  late DateTime now;
  late FakeAppUpdateGateway play;

  /// A fresh app launch: a new container around the same Play fake.
  AppUpdateNotifier notifier() {
    final container = ProviderContainer(
      overrides: [
        appUpdateGatewayProvider.overrideWithValue(play),
        nowProvider.overrideWithValue(() => now),
      ],
    );
    addTearDown(container.dispose);
    return container.read(appUpdateProvider.notifier);
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    now = DateTime(2026, 11, 15, 8);
    play = FakeAppUpdateGateway();
  });

  test('stays quiet when Play has nothing newer', () async {
    final n = notifier();
    await n.check();
    expect(n.state.phase, UpdatePhase.none);
    expect(n.state.prompt, isFalse);
  });

  test('offers a new version, and "Nanti saja" hides it for 3 days', () async {
    play.update = const AvailableUpdate(versionCode: 10);
    final first = notifier();
    await first.check();
    expect(first.state.phase, UpdatePhase.available);
    expect(first.state.prompt, isTrue);

    first.promptShown();
    await first.later();
    expect(first.state.prompt, isFalse);

    now = now.add(const Duration(days: 2));
    final nextLaunch = notifier();
    await nextLaunch.check();
    expect(nextLaunch.state.phase, UpdatePhase.available);
    expect(nextLaunch.state.prompt, isFalse);

    now = now.add(const Duration(days: 1, minutes: 1));
    final later = notifier();
    await later.check();
    expect(later.state.prompt, isTrue);
  });

  test('a snooze is per version: the next release asks again', () async {
    play.update = const AvailableUpdate(versionCode: 10);
    final n = notifier();
    await n.check();
    await n.later();

    play.update = const AvailableUpdate(versionCode: 11);
    final next = notifier();
    await next.check();
    expect(next.state.prompt, isTrue);
  });

  test('an important update is only snoozed for a day', () async {
    play.update = const AvailableUpdate(versionCode: 10, priority: 4);
    final n = notifier();
    await n.check();
    await n.later();

    now = now.add(const Duration(hours: 25));
    final next = notifier();
    await next.check();
    expect(next.state.prompt, isTrue);
  });

  test('downloads in the background, then offers to install', () async {
    play.update = const AvailableUpdate(versionCode: 10);
    final n = notifier();
    await n.check();

    final accepting = n.accept();
    expect(n.state.phase, UpdatePhase.downloading);
    expect(n.state.showBanner, isTrue);
    expect(play.downloads, 1);

    play.downloadResult.complete(UpdateDownloadResult.downloaded);
    await accepting;
    expect(n.state.phase, UpdatePhase.ready);
    expect(n.state.showBanner, isTrue);

    await n.install();
    expect(play.installs, 1);
  });

  test('declining Play\'s dialog counts as "Nanti saja"', () async {
    play.update = const AvailableUpdate(versionCode: 10);
    final n = notifier();
    await n.check();
    play.downloadResult.complete(UpdateDownloadResult.declined);
    await n.accept();

    expect(n.state.phase, UpdatePhase.available);
    expect(n.state.showBanner, isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt(AppUpdateNotifier.snoozeKey(10)), isNotNull);
  });

  test('a failed download is reported once and can be retried', () async {
    play.update = const AvailableUpdate(versionCode: 10);
    final n = notifier();
    await n.check();
    play.downloadResult.complete(UpdateDownloadResult.failed);
    await n.accept();

    expect(n.state.failed, isTrue);
    expect(n.state.phase, UpdatePhase.available);
    n.failureShown();
    expect(n.state.failed, isFalse);
  });

  test(
    'uses Play\'s full-screen update when background is not allowed',
    () async {
      play.update = const AvailableUpdate(
        versionCode: 10,
        flexibleAllowed: false,
        immediateAllowed: true,
      );
      final n = notifier();
      await n.check();
      await n.accept();

      expect(play.immediateRequests, 1);
      expect(play.downloads, 0);
      // Declined, so it is snoozed like "Nanti saja".
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt(AppUpdateNotifier.snoozeKey(10)), isNotNull);
    },
  );

  test('an update downloaded earlier goes straight to "Pasang"', () async {
    play.update = const AvailableUpdate(
      versionCode: 10,
      stage: UpdateStage.downloaded,
    );
    final n = notifier();
    await n.check();
    expect(n.state.phase, UpdatePhase.ready);
    expect(n.state.prompt, isFalse);
    expect(n.state.showBanner, isTrue);

    n.hideBanner();
    expect(n.state.showBanner, isFalse);
  });

  test('coming back to the app re-checks at most once an hour', () async {
    final n = notifier();
    await n.check();
    expect(play.checks, 1);

    now = now.add(const Duration(minutes: 20));
    await n.check(onResume: true);
    expect(play.checks, 1);

    now = now.add(const Duration(minutes: 41));
    await n.check(onResume: true);
    expect(play.checks, 2);
  });

  test('a running download is re-checked on every resume', () async {
    play.update = const AvailableUpdate(versionCode: 10);
    final n = notifier();
    await n.check();
    final accepting = n.accept();

    play.update = const AvailableUpdate(
      versionCode: 10,
      stage: UpdateStage.downloaded,
    );
    now = now.add(const Duration(minutes: 5));
    await n.check(onResume: true);
    expect(play.checks, 2);
    expect(n.state.phase, UpdatePhase.ready);

    play.downloadResult.complete(UpdateDownloadResult.downloaded);
    await accepting;
    expect(n.state.phase, UpdatePhase.ready);
  });
}
