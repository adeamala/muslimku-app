import 'package:flutter_test/flutter_test.dart';
import 'package:muslimku/features/prayer/domain/prayer_schedule.dart';
import 'package:muslimku/features/prayer/domain/prayer_time_model.dart';

PrayerSchedule _kediri() => PrayerSchedule.fromJson(const {
  'tanggal': 'Minggu, 25/10/2026',
  'imsak': '03:39',
  'subuh': '03:49',
  'terbit': '05:03',
  'dhuha': '05:30',
  'dzuhur': '11:20',
  'ashar': '14:29',
  'maghrib': '17:29',
  'isya': '18:40',
  'date': '2026-10-25',
});

DateTime _at(int h, int m, [int s = 0]) => DateTime(2026, 10, 25, h, m, s);

void main() {
  group('homeTimeline', () {
    test('lists the six home times in order, Terbit is not a prayer', () {
      final entries = homeTimeline(_kediri());
      expect(entries.map((e) => e.label), [
        'Subuh',
        'Terbit',
        'Dzuhur',
        'Ashar',
        'Maghrib',
        'Isya',
      ]);
      expect(entries.map((e) => e.time), [
        '03:49',
        '05:03',
        '11:20',
        '14:29',
        '17:29',
        '18:40',
      ]);
      expect(entries.where((e) => !e.isPrayer).map((e) => e.label), ['Terbit']);
    });
  });

  group('findNextPrayer', () {
    test('before Subuh the next prayer is today\'s Subuh', () {
      final next = findNextPrayer(_kediri(), _at(2, 10))!;
      expect(next.label, 'Subuh');
      expect(next.time, '03:49');
      expect(next.at, _at(3, 49));
      expect(next.isTomorrow, isFalse);
    });

    test('after Subuh it skips Terbit and points at Dzuhur', () {
      final next = findNextPrayer(_kediri(), _at(4, 30))!;
      expect(next.label, 'Dzuhur');
      expect(next.at, _at(11, 20));
    });

    test('at the exact minute the prayer counts as started', () {
      expect(findNextPrayer(_kediri(), _at(17, 29))!.label, 'Isya');
    });

    test('evening before Isya', () {
      final now = _at(18, 2, 12);
      final next = findNextPrayer(_kediri(), now)!;
      expect(next.label, 'Isya');
      expect(next.remaining(now), const Duration(minutes: 37, seconds: 48));
    });

    test('after Isya it rolls over to tomorrow\'s Subuh', () {
      final next = findNextPrayer(_kediri(), _at(21, 0))!;
      expect(next.label, 'Subuh');
      expect(next.isTomorrow, isTrue);
      expect(next.at, DateTime(2026, 10, 26, 3, 49));
    });

    test('returns null when the schedule has no usable times', () {
      final empty = PrayerSchedule.fromJson(const {});
      expect(findNextPrayer(empty, _at(12, 0)), isNull);
    });
  });

  group('timelineStates', () {
    test('marks passed times, the next prayer and the rest', () {
      final s = _kediri();
      final now = _at(18, 2);
      final states = timelineStates(
        homeTimeline(s),
        now,
        findNextPrayer(s, now),
      );
      expect(states, [
        TimelineState.passed,
        TimelineState.passed,
        TimelineState.passed,
        TimelineState.passed,
        TimelineState.passed,
        TimelineState.next,
      ]);
    });

    test('Terbit stays upcoming while Dzuhur is next', () {
      final s = _kediri();
      final now = _at(4, 0);
      final states = timelineStates(
        homeTimeline(s),
        now,
        findNextPrayer(s, now),
      );
      expect(states.sublist(0, 3), [
        TimelineState.passed,
        TimelineState.upcoming,
        TimelineState.next,
      ]);
    });

    test('after Isya every time of today has passed', () {
      final s = _kediri();
      final now = _at(22, 0);
      final states = timelineStates(
        homeTimeline(s),
        now,
        findNextPrayer(s, now),
      );
      expect(states, everyElement(TimelineState.passed));
    });
  });

  group('countdownLabel', () {
    test('rounds up to whole minutes', () {
      expect(
        countdownLabel(const Duration(minutes: 37, seconds: 48)),
        '38 menit lagi',
      );
      expect(countdownLabel(const Duration(minutes: 1)), '1 menit lagi');
    });

    test('uses hours when needed', () {
      expect(countdownLabel(const Duration(hours: 2)), '2 jam lagi');
      expect(
        countdownLabel(const Duration(hours: 1, minutes: 4, seconds: 1)),
        '1 jam 5 menit lagi',
      );
    });

    test('under a minute', () {
      expect(
        countdownLabel(const Duration(seconds: 59)),
        'Kurang dari 1 menit lagi',
      );
      expect(
        countdownLabel(const Duration(seconds: -5)),
        'Kurang dari 1 menit lagi',
      );
    });
  });

  group('titleCaseCity', () {
    test('turns MyQuran upper-case names into title case', () {
      expect(titleCaseCity('KOTA KEDIRI'), 'Kota Kediri');
      expect(titleCaseCity('KAB. BANYUWANGI'), 'Kab. Banyuwangi');
      expect(titleCaseCity('  kota  bandar lampung '), 'Kota Bandar Lampung');
      expect(titleCaseCity(''), '');
    });
  });
}
