import 'dart:convert';

import 'package:muslimku/features/prayer/domain/adzan_plan.dart'
    show AdzanPrayer, AdzanPrayerLabel;
import 'package:muslimku/features/prayer/domain/prayer_time_model.dart';

/// "HH:mm" moved by [minutes], wrapping at midnight; anything that is not a
/// time comes back unchanged.
String shiftHhmm(String hhmm, int minutes) {
  if (minutes == 0) return hhmm;
  final parts = hhmm.split(':');
  if (parts.length != 2) return hhmm;
  final h = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  if (h == null || m == null) return hhmm;
  final total = ((h * 60 + m + minutes) % 1440 + 1440) % 1440;
  final hh = (total ~/ 60).toString().padLeft(2, '0');
  final mm = (total % 60).toString().padLeft(2, '0');
  return '$hh:$mm';
}

/// Minutes added to each prayer time, so the schedule matches the local
/// mosque. Imsak follows Subuh (it is Subuh − 10 in the Kemenag schedule);
/// Terbit and Dhuha are never moved.
class PrayerOffsets {
  const PrayerOffsets(this._minutes);

  static const none = PrayerOffsets({});

  /// Largest correction in either direction, in minutes.
  static const limit = 15;

  final Map<AdzanPrayer, int> _minutes;

  int of(AdzanPrayer prayer) => _minutes[prayer] ?? 0;

  bool get isZero => AdzanPrayer.values.every((p) => of(p) == 0);

  PrayerOffsets set(AdzanPrayer prayer, int minutes) {
    final next = Map<AdzanPrayer, int>.from(_minutes);
    final clamped = minutes.clamp(-limit, limit);
    if (clamped == 0) {
      next.remove(prayer);
    } else {
      next[prayer] = clamped;
    }
    return PrayerOffsets(next);
  }

  /// [day] with every prayer moved by its offset; the same object when there
  /// is nothing to move.
  PrayerSchedule apply(PrayerSchedule day) {
    if (isZero) return day;
    final subuh = of(AdzanPrayer.subuh);
    return PrayerSchedule.fromJson({
      ...day.toJson(),
      'imsak': shiftHhmm(day.imsak, subuh),
      'subuh': shiftHhmm(day.subuh, subuh),
      'dzuhur': shiftHhmm(day.dzuhur, of(AdzanPrayer.dzuhur)),
      'ashar': shiftHhmm(day.ashar, of(AdzanPrayer.ashar)),
      'maghrib': shiftHhmm(day.maghrib, of(AdzanPrayer.maghrib)),
      'isya': shiftHhmm(day.isya, of(AdzanPrayer.isya)),
    });
  }

  /// "Subuh +2 · Maghrib −1", or "Belum ada koreksi".
  String get summary {
    final parts = [
      for (final p in AdzanPrayer.values)
        if (of(p) != 0) '${p.label} ${signed(of(p))}',
    ];
    return parts.isEmpty ? 'Belum ada koreksi' : parts.join(' · ');
  }

  /// "+2" / "−1" (typographic minus) / "0".
  static String signed(int minutes) => minutes > 0
      ? '+$minutes'
      : minutes < 0
      ? '−${-minutes}'
      : '0';

  String toJson() =>
      jsonEncode({for (final e in _minutes.entries) e.key.name: e.value});

  static PrayerOffsets fromJson(String? json) {
    if (json == null || json.isEmpty) return none;
    try {
      final map = jsonDecode(json);
      if (map is! Map) return none;
      var out = none;
      for (final p in AdzanPrayer.values) {
        final v = map[p.name];
        if (v is num) out = out.set(p, v.toInt());
      }
      return out;
    } catch (_) {
      return none;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is PrayerOffsets &&
      AdzanPrayer.values.every((p) => of(p) == other.of(p));

  @override
  int get hashCode =>
      Object.hashAll([for (final p in AdzanPrayer.values) of(p)]);

  @override
  String toString() => 'PrayerOffsets($summary)';
}
