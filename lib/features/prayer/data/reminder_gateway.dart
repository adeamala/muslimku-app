import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show MethodChannel;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muslimku/core/storage/local_store.dart'
    show runningInFlutterTest;
import 'package:muslimku/features/prayer/domain/adzan_plan.dart';
import 'package:timezone/timezone.dart' as tz;

/// Local notifications for adzan reminders. Everything happens on the phone.
abstract class ReminderGateway {
  /// Whether notifications may be shown; asks the user when [request] is true
  /// (Android 13+).
  Future<bool> notificationsAllowed({bool request = false});

  /// Whether alarms may fire at the exact minute (Android 12+ asks the user).
  Future<bool> exactAlarmsAllowed();

  /// Opens the system screen where the user allows exact alarms.
  Future<void> requestExactAlarms();

  /// Opens the system screen with this app's notification settings (for when
  /// the permission was refused and Android no longer asks).
  Future<void> openNotificationSettings();

  /// Whether the app is exempt from battery optimisation. Restricted apps may
  /// get their alarms delayed or dropped on some phones.
  Future<bool> batteryUnrestricted();

  /// Opens the system list where the user lifts the battery restriction.
  Future<void> openBatterySettings();

  /// Shows [reminder] right now, on the channel of its sound, so the user can
  /// check that reminders appear and sound as expected.
  Future<void> showNow(AdzanReminder reminder);

  /// Cancels every scheduled reminder and schedules [reminders].
  Future<void> replaceAll(List<AdzanReminder> reminders, {required bool exact});

  Future<void> cancelAll();
}

class LocalReminderGateway implements ReminderGateway {
  LocalReminderGateway([FlutterLocalNotificationsPlugin? plugin])
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  Future<void>? _init;

  /// Channel of the prayer-time and sahur reminders for [sound]. Android
  /// never changes a channel's sound once created, hence one channel per sound.
  static AndroidNotificationDetails channelFor(AdzanSound sound) {
    final resource = sound.resource;
    return AndroidNotificationDetails(
      sound.channelId,
      sound == AdzanSound.bawaan
          ? 'Pengingat adzan'
          : 'Pengingat adzan · ${sound.label}',
      channelDescription: sound == AdzanSound.bawaan
          ? 'Pemberitahuan saat masuk waktu sholat'
          : 'Pemberitahuan saat masuk waktu sholat (suara ${sound.label.toLowerCase()})',
      importance: Importance.high,
      priority: Priority.high,
      category: AndroidNotificationCategory.reminder,
      icon: 'ic_stat_adzan',
      playSound: sound != AdzanSound.senyap,
      sound: resource == null
          ? null
          : RawResourceAndroidNotificationSound(resource),
    );
  }

  static const _earlyChannel = AndroidNotificationDetails(
    'adzan_early',
    'Pengingat sebelum adzan',
    channelDescription: 'Pemberitahuan 10 menit sebelum waktu sholat',
    importance: Importance.defaultImportance,
    priority: Priority.defaultPriority,
    category: AndroidNotificationCategory.reminder,
    icon: 'ic_stat_adzan',
  );

  /// Tahajjud, Al-Kahfi, fasting and daily reminders: one channel, system
  /// sound, default importance (they are never urgent like the adzan).
  static const extrasChannel = AndroidNotificationDetails(
    'adzan_lainnya',
    'Pengingat lainnya',
    channelDescription:
        'Tahajjud, Al-Kahfi hari Jumat, puasa sunnah, ayat & hadits hari ini',
    importance: Importance.defaultImportance,
    priority: Priority.defaultPriority,
    category: AndroidNotificationCategory.reminder,
    icon: 'ic_stat_adzan',
  );

  static const _renewalChannel = AndroidNotificationDetails(
    'adzan_renewal',
    'Perpanjang pengingat adzan',
    channelDescription: 'Pemberitahuan saat pengingat adzan hampir habis',
    importance: Importance.defaultImportance,
    priority: Priority.defaultPriority,
    category: AndroidNotificationCategory.reminder,
    icon: 'ic_stat_adzan',
  );

  Future<void> _ready() => _init ??= _plugin
      .initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('ic_stat_adzan'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
      )
      .then((_) {});

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  @override
  Future<bool> notificationsAllowed({bool request = false}) async {
    await _ready();
    final android = _android;
    if (android != null) {
      final enabled = await android.areNotificationsEnabled() ?? true;
      if (enabled || !request) return enabled;
      return await android.requestNotificationsPermission() ?? false;
    }
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (ios != null && request) {
      return await ios.requestPermissions(alert: true, sound: true) ?? false;
    }
    return true;
  }

  @override
  Future<bool> exactAlarmsAllowed() async {
    await _ready();
    return await _android?.canScheduleExactNotifications() ?? true;
  }

  @override
  Future<void> requestExactAlarms() async {
    await _ready();
    await _android?.requestExactAlarmsPermission();
  }

  @override
  Future<void> replaceAll(
    List<AdzanReminder> reminders, {
    required bool exact,
  }) async {
    await _ready();
    await _plugin.cancelAll();
    for (final r in reminders) {
      final note = r.note;
      final android = r.renewal
          ? _renewalChannel
          : r.extra != null
          ? extrasChannel
          : r.early
          ? _earlyChannel
          : channelFor(r.sound);
      await _plugin.zonedSchedule(
        id: r.id,
        title: r.title,
        body: note == null ? r.body : '${r.body}\n$note',
        // One-off alarms only need the instant; UTC avoids time-zone lookups.
        scheduledDate: tz.TZDateTime.from(r.at, tz.UTC),
        notificationDetails: NotificationDetails(
          android: note == null
              ? android
              : AndroidNotificationDetails(
                  android.channelId,
                  android.channelName,
                  channelDescription: android.channelDescription,
                  importance: android.importance,
                  priority: android.priority,
                  category: android.category,
                  icon: android.icon,
                  playSound: android.playSound,
                  sound: android.sound,
                  // The second line (hadith of the day) shows when expanded.
                  styleInformation: BigTextStyleInformation('${r.body}\n$note'),
                ),
          iOS: const DarwinNotificationDetails(presentSound: true),
        ),
        androidScheduleMode: exact
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }

  @override
  Future<void> cancelAll() async {
    await _ready();
    await _plugin.cancelAll();
  }

  /// Battery and settings screens are not covered by the notifications
  /// plugin; MainActivity answers these.
  static const _system = MethodChannel('com.muslimku/reminders');

  static bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  Future<void> openNotificationSettings() async {
    if (!_isAndroid) return;
    await _system.invokeMethod<void>('openNotificationSettings');
  }

  @override
  Future<bool> batteryUnrestricted() async {
    if (!_isAndroid) return true;
    return await _system.invokeMethod<bool>('batteryUnrestricted') ?? true;
  }

  @override
  Future<void> openBatterySettings() async {
    if (!_isAndroid) return;
    await _system.invokeMethod<void>('openBatterySettings');
  }

  /// Id of the test notification; above every planned one.
  static const testId = 2147000000;

  @override
  Future<void> showNow(AdzanReminder reminder) async {
    await _ready();
    await _plugin.show(
      id: testId,
      title: reminder.title,
      body: reminder.body,
      notificationDetails: NotificationDetails(
        android: channelFor(reminder.sound),
        iOS: const DarwinNotificationDetails(presentSound: true),
      ),
    );
  }
}

/// The web build used for visual checks has no notifications.
class NoReminderGateway implements ReminderGateway {
  const NoReminderGateway();

  @override
  Future<bool> notificationsAllowed({bool request = false}) async => true;

  @override
  Future<bool> exactAlarmsAllowed() async => true;

  @override
  Future<void> requestExactAlarms() async {}

  @override
  Future<void> openNotificationSettings() async {}

  @override
  Future<bool> batteryUnrestricted() async => true;

  @override
  Future<void> openBatterySettings() async {}

  @override
  Future<void> showNow(AdzanReminder reminder) async {}

  @override
  Future<void> replaceAll(
    List<AdzanReminder> reminders, {
    required bool exact,
  }) async {}

  @override
  Future<void> cancelAll() async {}
}

final reminderGatewayProvider = Provider<ReminderGateway>(
  (ref) => kIsWeb || runningInFlutterTest
      ? const NoReminderGateway()
      : LocalReminderGateway(),
);
