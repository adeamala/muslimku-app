import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muslimku/core/state/mounted_flag.dart';
import 'package:muslimku/core/time/clock_provider.dart';
import 'package:muslimku/features/hadith/application/hadits_providers.dart'
    show haditsRepositoryProvider;
import 'package:muslimku/features/hadith/domain/hadith_model.dart';
import 'package:muslimku/features/location/application/location_provider.dart';
import 'package:muslimku/features/prayer/application/prayer_offsets_provider.dart';
import 'package:muslimku/features/prayer/data/prayer_schedule_repository.dart';
import 'package:muslimku/features/prayer/data/reminder_gateway.dart';
import 'package:muslimku/features/prayer/domain/adzan_plan.dart';
import 'package:muslimku/features/prayer/domain/prayer_offsets.dart';
import 'package:muslimku/features/prayer/domain/prayer_schedule.dart';
import 'package:muslimku/features/prayer/domain/prayer_time_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AdzanState {
  const AdzanState({
    this.settings = const AdzanSettings(),
    this.notificationsDenied = false,
    this.exactAllowed = true,
    this.scheduled = 0,
    this.next,
    this.busy = false,
    this.message,
  });

  final AdzanSettings settings;

  /// The user refused notifications; reminders cannot be shown.
  final bool notificationsDenied;

  /// Without exact alarms Android may deliver reminders a few minutes late.
  final bool exactAllowed;

  /// Reminders currently scheduled.
  final int scheduled;

  /// The first scheduled reminder (not the renewal notice), for "Cek
  /// pengingat".
  final AdzanReminder? next;
  final bool busy;

  /// Problem to show under the switch (e.g. no saved schedule).
  final String? message;

  AdzanState copyWith({
    AdzanSettings? settings,
    bool? notificationsDenied,
    bool? exactAllowed,
    int? scheduled,
    Object? next = _keep,
    bool? busy,
    Object? message = _keep,
  }) => AdzanState(
    settings: settings ?? this.settings,
    notificationsDenied: notificationsDenied ?? this.notificationsDenied,
    exactAllowed: exactAllowed ?? this.exactAllowed,
    scheduled: scheduled ?? this.scheduled,
    next: identical(next, _keep) ? this.next : next as AdzanReminder?,
    busy: busy ?? this.busy,
    message: identical(message, _keep) ? this.message : message as String?,
  );
}

const Object _keep = Object();

/// Adzan reminders: settings saved on the phone, reminders planned from the
/// saved monthly schedule for the next 14 days and refreshed on every start,
/// city change and settings change.
final adzanProvider = NotifierProvider<AdzanNotifier, AdzanState>(
  AdzanNotifier.new,
);

class AdzanNotifier extends Notifier<AdzanState> {
  late DateTime Function() _clock;
  late MountedFlag _alive;
  late Future<void> ready;

  @override
  AdzanState build() {
    _clock = ref.watch(nowProvider);
    _alive = MountedFlag(ref);
    ready = _load();
    ref.listen<String?>(locationProvider.select((s) => s.selectedCityId), (
      previous,
      next,
    ) {
      if (previous != next) unawaited(reschedule());
    });
    ref.listen<PrayerOffsets>(prayerOffsetsProvider, (previous, next) {
      if (previous != next) unawaited(reschedule());
    });
    return const AdzanState();
  }

  static const enabledKey = 'adzan_enabled';
  static const prayersKey = 'adzan_prayers';
  static const beforeKey = 'adzan_remind_before';
  static const soundKey = 'adzan_sound';
  static const sahurKey = 'adzan_sahur';
  static const extrasKey = 'adzan_extras';

  ReminderGateway get _gateway => ref.read(reminderGatewayProvider);

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final names = prefs.getStringList(prayersKey);
    if (!_alive.mounted) return;
    state = state.copyWith(
      settings: AdzanSettings(
        enabled: prefs.getBool(enabledKey) ?? false,
        prayers: names == null
            ? {...AdzanPrayer.values}
            : {
                for (final p in AdzanPrayer.values)
                  if (names.contains(p.name)) p,
              },
        remindBefore: prefs.getBool(beforeKey) ?? true,
        sound: AdzanSound.byName(prefs.getString(soundKey)),
        sahur: prefs.getBool(sahurKey) ?? false,
        extras: {
          for (final name in prefs.getStringList(extrasKey) ?? const <String>[])
            if (ExtraReminder.byName(name) case final e?) e,
        },
      ),
    );
  }

  Future<void> _save(AdzanSettings s) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(enabledKey, s.enabled);
    await prefs.setStringList(prayersKey, [for (final p in s.prayers) p.name]);
    await prefs.setBool(beforeKey, s.remindBefore);
    await prefs.setString(soundKey, s.sound.name);
    await prefs.setBool(sahurKey, s.sahur);
    await prefs.setStringList(extrasKey, [
      for (final e in ExtraReminder.values)
        if (s.extras.contains(e)) e.name,
    ]);
  }

  /// Turning on asks for the notification permission first.
  Future<void> setEnabled(bool on) async {
    await ready;
    if (on) {
      bool allowed;
      try {
        allowed = await _gateway.notificationsAllowed(request: true);
      } catch (_) {
        allowed = false;
      }
      if (!_alive.mounted) return;
      if (!allowed) {
        state = state.copyWith(notificationsDenied: true);
        return;
      }
    }
    await _update(
      state.settings.copyWith(enabled: on),
      notificationsDenied: false,
    );
  }

  Future<void> togglePrayer(AdzanPrayer prayer) async {
    await ready;
    final prayers = {...state.settings.prayers};
    if (!prayers.remove(prayer)) prayers.add(prayer);
    await _update(state.settings.copyWith(prayers: prayers));
  }

  Future<void> setRemindBefore(bool on) async {
    await ready;
    await _update(state.settings.copyWith(remindBefore: on));
  }

  Future<void> setSound(AdzanSound sound) async {
    await ready;
    await _update(state.settings.copyWith(sound: sound));
  }

  Future<void> setSahur(bool on) async {
    await ready;
    await _update(state.settings.copyWith(sahur: on));
  }

  Future<void> toggleExtra(ExtraReminder extra) async {
    await ready;
    final extras = {...state.settings.extras};
    if (!extras.remove(extra)) extras.add(extra);
    await _update(state.settings.copyWith(extras: extras));
  }

  Future<void> requestExactAlarms() async {
    try {
      await _gateway.requestExactAlarms();
    } catch (_) {}
    await reschedule();
  }

  /// Shows a reminder right now with the chosen sound, so the user can check
  /// that reminders appear and sound. Returns false when the phone refused.
  Future<bool> testNow() async {
    await ready;
    final location = ref.read(locationProvider);
    final city = titleCaseCity(location.cityName);
    try {
      await _gateway.showNow(
        AdzanReminder(
          id: 0,
          at: _clock(),
          prayer: null,
          early: false,
          sound: state.settings.sound,
          title: 'Percobaan pengingat adzan',
          body: 'Begini pengingat Muslimku akan muncul · $city',
        ),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _update(AdzanSettings next, {bool? notificationsDenied}) async {
    if (!_alive.mounted) return;
    state = state.copyWith(
      settings: next,
      notificationsDenied: notificationsDenied,
    );
    await _save(next);
    await reschedule(cancelWhenOff: true);
  }

  /// Plans the reminders again. When reminders are off nothing is touched,
  /// unless [cancelWhenOff] (the user just switched them off).
  Future<void> reschedule({bool cancelWhenOff = false}) async {
    await ready;
    if (!_alive.mounted) return;
    final settings = state.settings;
    if (!settings.enabled) {
      if (cancelWhenOff) {
        try {
          await _gateway.cancelAll();
        } catch (_) {}
      }
      if (_alive.mounted) {
        state = state.copyWith(scheduled: 0, next: null, message: null);
      }
      return;
    }
    state = state.copyWith(busy: true);
    final location = ref.read(locationProvider);
    final cityId = location.cityId;
    final city = titleCaseCity(location.cityName);
    final now = _clock();
    List<PrayerSchedule> days;
    try {
      final offsets = ref.read(prayerOffsetsProvider);
      days = [
        for (final day
            in await ref
                .read(prayerScheduleRepositoryProvider)
                .upcoming(cityId, now, days: AdzanPlan.horizon.inDays))
          offsets.apply(day),
      ];
    } catch (_) {
      if (!_alive.mounted) return;
      state = state.copyWith(
        busy: false,
        message:
            'Jadwal $city belum tersimpan. Sambungkan internet sekali '
            'agar pengingat bisa disiapkan.',
      );
      return;
    }
    final reminders = AdzanPlan.build(
      days: days,
      settings: settings,
      now: now,
      city: city,
      hadithFor: await _hadithOfDay(),
    );
    try {
      final exact = await _gateway.exactAlarmsAllowed();
      await _gateway.replaceAll(reminders, exact: exact);
      if (!_alive.mounted) return;
      final planned = reminders.where((r) => !r.renewal).toList();
      state = state.copyWith(
        busy: false,
        // Pengaturan counts the prayer reminders, not the renewal notice.
        scheduled: planned.length,
        next: planned.firstOrNull,
        exactAllowed: exact,
        message: null,
      );
    } catch (_) {
      if (!_alive.mounted) return;
      state = state.copyWith(
        busy: false,
        message: 'Pengingat belum bisa dipasang di HP ini.',
      );
    }
  }

  /// "Hadits hari ini" for the first reminder of each day, from the Arbain
  /// list saved on the phone. Null until the list has been saved once; the
  /// plan never waits for the network.
  Future<String? Function(DateTime)?> _hadithOfDay() async {
    List<HaditsEntry>? items;
    try {
      items = await ref.read(haditsRepositoryProvider).savedArbain();
    } catch (_) {
      return null;
    }
    if (items == null || items.isEmpty) return null;
    final titles = {for (final item in items) item.number: item.title};
    final count = items.length;
    return (DateTime date) =>
        adzanHadithLine(date, titles: titles, count: count);
  }
}
