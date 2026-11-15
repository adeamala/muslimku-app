import 'dart:convert';

import 'package:muslimku/features/prayer/domain/prayer_time_model.dart';

/// What the Android home-screen widget reads from its shared preferences
/// (written by `publishWidget` in MainActivity): the city and up to seven
/// days of times.
/// `PrayerWidgetProvider.kt` picks today's row and the next prayer itself,
/// so the widget stays right without the app running.
abstract final class WidgetPayload {
  static const cityKey = 'widget_city';
  static const daysKey = 'widget_days';
  static const updatedKey = 'widget_updated';
  static const keys = {cityKey, daysKey, updatedKey};

  static const maxDays = 7;

  static String _two(int n) => n.toString().padLeft(2, '0');

  static Map<String, String> build({
    required String city,
    required List<PrayerSchedule> days,
    required DateTime updatedAt,
  }) {
    final rows = [
      for (final d in days)
        if (d.date.isNotEmpty)
          {
            'date': d.date,
            'imsak': d.imsak,
            'subuh': d.subuh,
            'dzuhur': d.dzuhur,
            'ashar': d.ashar,
            'maghrib': d.maghrib,
            'isya': d.isya,
          },
    ]..sort((a, b) => a['date']!.compareTo(b['date']!));
    return {
      cityKey: city,
      daysKey: jsonEncode(rows.take(maxDays).toList()),
      updatedKey:
          '${updatedAt.year}-${_two(updatedAt.month)}-${_two(updatedAt.day)}'
          'T${_two(updatedAt.hour)}:${_two(updatedAt.minute)}',
    };
  }
}
