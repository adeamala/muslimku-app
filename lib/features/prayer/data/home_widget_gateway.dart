import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Hands the prayer schedule to the Android home-screen widget.
abstract class HomeWidgetGateway {
  /// False where there is no widget (web, tests): nothing is written.
  bool get supported;

  Future<void> publish(Map<String, String> data);
}

class NoHomeWidgetGateway implements HomeWidgetGateway {
  const NoHomeWidgetGateway();

  @override
  bool get supported => false;

  @override
  Future<void> publish(Map<String, String> data) async {}
}

/// Hands the data to `MainActivity.kt` (`publishWidget`), which stores it in
/// the widget's SharedPreferences and redraws `PrayerWidgetProvider`. No
/// plugin: `home_widget` would pull in Glance/WorkManager and minSdk 23.
class AndroidHomeWidgetGateway implements HomeWidgetGateway {
  const AndroidHomeWidgetGateway();

  static const channel = MethodChannel('com.muslimku/reminders');

  @override
  bool get supported => true;

  @override
  Future<void> publish(Map<String, String> data) async {
    try {
      await channel.invokeMethod<bool>('publishWidget', data);
    } on PlatformException catch (_) {
      // Old native side without the method: nothing to do.
    } on MissingPluginException catch (_) {}
  }
}

final homeWidgetGatewayProvider = Provider<HomeWidgetGateway>((ref) {
  final android = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  return android
      ? const AndroidHomeWidgetGateway()
      : const NoHomeWidgetGateway();
});
