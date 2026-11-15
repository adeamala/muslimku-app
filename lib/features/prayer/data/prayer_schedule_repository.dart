import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muslimku/core/network/api_service.dart';
import 'package:muslimku/core/storage/content_cache.dart';
import 'package:muslimku/features/prayer/domain/prayer_time_model.dart';

/// A month of prayer times for one city.
class PrayerMonth {
  const PrayerMonth({
    required this.cityId,
    required this.city,
    required this.region,
    required this.days,
  });

  factory PrayerMonth.fromJson(Map<String, dynamic> json) => PrayerMonth(
    cityId: '${json['id'] ?? ''}',
    city: '${json['lokasi'] ?? ''}',
    region: '${json['daerah'] ?? ''}',
    days: [
      for (final day in (json['jadwal'] as List? ?? const []))
        PrayerSchedule.fromJson(Map<String, dynamic>.from(day as Map)),
    ],
  );

  final String cityId;
  final String city;
  final String region;
  final List<PrayerSchedule> days;

  PrayerSchedule? day(DateTime date) {
    final iso = _iso(date);
    for (final d in days) {
      if (d.date == iso) return d;
    }
    return null;
  }

  PrayerTimeModel? modelFor(DateTime date) {
    final schedule = day(date);
    if (schedule == null) return null;
    return PrayerTimeModel(
      id: cityId,
      lokasi: city,
      daerah: region,
      jadwal: schedule,
    );
  }
}

String _two(int n) => n.toString().padLeft(2, '0');
String _iso(DateTime d) => '${d.year}-${_two(d.month)}-${_two(d.day)}';

/// Monthly schedules (`sholat/jadwal/<city>/<yyyy>/<mm>`) saved on the phone,
/// so Beranda keeps its times offline and adzan reminders can be planned.
class PrayerScheduleRepository {
  PrayerScheduleRepository({required this.api, required this.cache});

  final ApiService api;
  final ContentCache cache;

  static String key(String cityId, int year, int month) =>
      'jadwal/${cityId}_$year-${_two(month)}.json';

  Future<PrayerMonth> month(String cityId, int year, int month) async {
    final result = await cache.object(
      key(cityId, year, month),
      () async {
        final data = await api.getJson(
          'sholat/jadwal/$cityId/$year/${_two(month)}',
        );
        return data is Map ? Map<String, dynamic>.from(data) : null;
      },
      // Times are fixed for the month; refresh only if the copy is old.
      maxAge: const Duration(days: 20),
    );
    return PrayerMonth.fromJson(result.data);
  }

  /// The saved month only, without a request.
  Future<PrayerMonth?> savedMonth(String cityId, int year, int month) async {
    final saved = await cache.peek(key(cityId, year, month));
    final data = saved?.data;
    return data is Map
        ? PrayerMonth.fromJson(Map<String, dynamic>.from(data))
        : null;
  }

  /// Days from [from] on: this month and, near its end, the next one.
  Future<List<PrayerSchedule>> upcoming(
    String cityId,
    DateTime from, {
    int days = 14,
  }) async {
    final out = <PrayerSchedule>[];
    final first = await month(cityId, from.year, from.month);
    out.addAll(first.days);
    final last = from.add(Duration(days: days));
    if (last.month != from.month || last.year != from.year) {
      try {
        out.addAll((await month(cityId, last.year, last.month)).days);
      } catch (_) {}
    }
    final today = _iso(from);
    return out.where((d) => d.date.compareTo(today) >= 0).toList();
  }
}

final prayerScheduleRepositoryProvider = Provider<PrayerScheduleRepository>(
  (ref) => PrayerScheduleRepository(
    api: ref.watch(apiServiceProvider),
    cache: ref.watch(contentCacheProvider),
  ),
);
