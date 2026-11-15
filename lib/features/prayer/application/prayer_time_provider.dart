import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:muslimku/core/network/api_service.dart';
import 'package:muslimku/core/state/mounted_flag.dart';
import 'package:muslimku/core/storage/content_cache.dart';
import 'package:muslimku/features/location/domain/default_city.dart';
import 'package:muslimku/features/prayer/application/prayer_offsets_provider.dart';
import 'package:muslimku/features/prayer/data/prayer_schedule_repository.dart';
import 'package:muslimku/features/prayer/domain/prayer_offsets.dart';
import 'package:muslimku/features/prayer/domain/prayer_time_model.dart';

/// Today's prayer times for the chosen city, with the user's corrections.
final prayerTimeProvider =
    NotifierProvider<PrayerTimeNotifier, PrayerTimeState>(
      PrayerTimeNotifier.new,
    );

class PrayerTimeState {
  final PrayerTimeModel? prayerTime;
  final bool isLoading;
  final String? error;
  final String? nextPrayer;
  final String? timeRemaining;
  final String? nextPrayerTime;

  /// Times come from the month saved on the phone because the request failed.
  final bool fromSaved;

  PrayerTimeState({
    this.prayerTime,
    this.isLoading = false,
    this.error,
    this.nextPrayer,
    this.timeRemaining,
    this.nextPrayerTime,
    this.fromSaved = false,
  });

  PrayerTimeState copyWith({
    PrayerTimeModel? prayerTime,
    bool? isLoading,
    Object? error = _keepError,
    String? nextPrayer,
    String? timeRemaining,
    String? nextPrayerTime,
    bool? fromSaved,
  }) {
    return PrayerTimeState(
      prayerTime: prayerTime ?? this.prayerTime,
      isLoading: isLoading ?? this.isLoading,
      // Passing `error: null` must clear the error; omitting it keeps the old one.
      error: identical(error, _keepError) ? this.error : error as String?,
      nextPrayer: nextPrayer ?? this.nextPrayer,
      timeRemaining: timeRemaining ?? this.timeRemaining,
      nextPrayerTime: nextPrayerTime ?? this.nextPrayerTime,
      fromSaved: fromSaved ?? this.fromSaved,
    );
  }
}

const Object _keepError = Object();

class PrayerTimeNotifier extends Notifier<PrayerTimeState> {
  late ApiService _apiService;
  late PrayerScheduleRepository? _schedules;
  late void Function()? _onOffline;
  late void Function()? _onOnline;
  late MountedFlag _alive;

  /// The day as MyQuran sent it; [state] holds it with the offsets applied.
  PrayerTimeModel? _raw;

  @override
  PrayerTimeState build() {
    _apiService = ref.read(apiServiceProvider);
    _schedules = ref.read(prayerScheduleRepositoryProvider);
    final status = ref.read(networkStatusProvider.notifier);
    _onOffline = status.markOffline;
    _onOnline = status.markOnline;
    _alive = MountedFlag(ref);
    _raw = null;
    // A changed correction re-shifts the loaded day; no request needed.
    ref.listen<PrayerOffsets>(prayerOffsetsProvider, (previous, next) {
      if (previous != next) reapplyOffsets();
    });
    return PrayerTimeState();
  }

  PrayerOffsets _offsets() => ref.read(prayerOffsetsProvider);

  Future<void> loadPrayerTimes({String cityId = DefaultCity.id}) async {
    state = state.copyWith(isLoading: true, error: null);
    final now = DateTime.now();

    // The month saved on the phone shows at once; the request below only
    // refreshes it, so a weak signal never leaves Beranda waiting.
    final saved = await _savedDay(cityId, now);
    if (!_alive.mounted) return;
    if (saved != null) _apply(saved, fromSaved: true);

    try {
      final today = DateFormat('yyyy-MM-dd').format(now);
      final json = await _apiService.getPrayerTimes(cityId, today);
      final prayerTime = json == null ? null : PrayerTimeModel.fromJson(json);

      if (prayerTime != null) {
        _apply(prayerTime, fromSaved: false);
        _onOnline?.call();
        return;
      }
    } catch (_) {
      // Keep the saved day below.
    }

    if (!_alive.mounted) return;
    if (saved != null) {
      _onOffline?.call();
      return;
    }
    state = state.copyWith(
      isLoading: false,
      error: 'Gagal memuat jadwal sholat',
    );
  }

  /// Shifts the loaded day again with the current offsets.
  void reapplyOffsets() {
    final raw = _raw;
    if (raw != null) _apply(raw, fromSaved: state.fromSaved);
  }

  void _apply(PrayerTimeModel raw, {required bool fromSaved}) {
    if (!_alive.mounted) return;
    _raw = raw;
    final prayerTime = raw.withJadwal(_offsets().apply(raw.jadwal));
    final nextPrayerInfo = _calculateNextPrayer(prayerTime.jadwal);
    state = state.copyWith(
      prayerTime: prayerTime,
      isLoading: false,
      error: null,
      nextPrayer: nextPrayerInfo['name'],
      timeRemaining: nextPrayerInfo['remaining'],
      nextPrayerTime: nextPrayerInfo['time'],
      fromSaved: fromSaved,
    );
  }

  Future<PrayerTimeModel?> _savedDay(String cityId, DateTime now) async {
    try {
      final month = await _schedules?.savedMonth(cityId, now.year, now.month);
      return month?.modelFor(now);
    } catch (_) {
      return null;
    }
  }

  Map<String, String> _calculateNextPrayer(PrayerSchedule schedule) {
    final now = DateTime.now();
    final today = DateFormat('yyyy-MM-dd').format(now);

    final prayerTimes = [
      {'name': 'Shubuh', 'time': schedule.subuh},
      {'name': 'Dhuhur', 'time': schedule.dzuhur},
      {'name': 'Ashar', 'time': schedule.ashar},
      {'name': 'Maghrib', 'time': schedule.maghrib},
      {'name': 'Isya\'', 'time': schedule.isya},
    ];

    for (final prayer in prayerTimes) {
      final prayerDateTime = DateTime.parse('$today ${prayer['time']}:00');
      if (now.isBefore(prayerDateTime)) {
        final difference = prayerDateTime.difference(now);
        return {
          'name': prayer['name']!,
          'remaining': _formatRemainingDuration(difference),
          'time': prayer['time']!,
        };
      }
    }

    // If no prayer is left today, return next day's Shubuh
    final tomorrow = now.add(const Duration(days: 1));
    final tomorrowShubuh = DateTime.parse(
      '${DateFormat('yyyy-MM-dd').format(tomorrow)} ${schedule.subuh}:00',
    );
    final difference = tomorrowShubuh.difference(now);

    return {
      'name': 'Shubuh',
      'remaining': _formatRemainingDuration(difference),
      'time': schedule.subuh,
    };
  }

  void updateTimeRemaining() {
    if (state.prayerTime != null) {
      final nextPrayerInfo = _calculateNextPrayer(state.prayerTime!.jadwal);
      state = state.copyWith(
        nextPrayer: nextPrayerInfo['name'],
        timeRemaining: nextPrayerInfo['remaining'],
        nextPrayerTime: nextPrayerInfo['time'],
      );
    }
  }

  String _formatRemainingDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;

    final hoursLabel = '${hours.toString().padLeft(2, '0')} Jam';
    final minutesLabel = '${minutes.toString().padLeft(2, '0')} Menit';

    return '$hoursLabel $minutesLabel';
  }
}
