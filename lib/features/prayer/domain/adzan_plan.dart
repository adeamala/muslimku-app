import 'package:muslimku/core/utils/daily_pick.dart';
import 'package:muslimku/features/prayer/domain/prayer_time_model.dart';

/// The five daily prayers that can get a reminder, in day order.
enum AdzanPrayer { subuh, dzuhur, ashar, maghrib, isya }

extension AdzanPrayerLabel on AdzanPrayer {
  String get label => switch (this) {
    AdzanPrayer.subuh => 'Subuh',
    AdzanPrayer.dzuhur => 'Dzuhur',
    AdzanPrayer.ashar => 'Ashar',
    AdzanPrayer.maghrib => 'Maghrib',
    AdzanPrayer.isya => 'Isya',
  };

  String timeIn(PrayerSchedule day) => switch (this) {
    AdzanPrayer.subuh => day.subuh,
    AdzanPrayer.dzuhur => day.dzuhur,
    AdzanPrayer.ashar => day.ashar,
    AdzanPrayer.maghrib => day.maghrib,
    AdzanPrayer.isya => day.isya,
  };
}

class AdzanSettings {
  const AdzanSettings({
    this.enabled = false,
    this.prayers = const {...AdzanPrayer.values},
    this.remindBefore = true,
    this.sound = AdzanSound.bawaan,
    this.sahur = false,
    this.extras = const {},
  });

  final bool enabled;
  final Set<AdzanPrayer> prayers;

  /// Also remind [AdzanPlan.leadTime] before each prayer.
  final bool remindBefore;

  /// Sound of the prayer-time and sahur reminders.
  final AdzanSound sound;

  /// Also remind [AdzanPlan.sahurLead] before Imsak (for those fasting).
  final bool sahur;

  /// Extra reminders besides the prayer times.
  final Set<ExtraReminder> extras;

  AdzanSettings copyWith({
    bool? enabled,
    Set<AdzanPrayer>? prayers,
    bool? remindBefore,
    AdzanSound? sound,
    bool? sahur,
    Set<ExtraReminder>? extras,
  }) => AdzanSettings(
    enabled: enabled ?? this.enabled,
    prayers: prayers ?? this.prayers,
    remindBefore: remindBefore ?? this.remindBefore,
    sound: sound ?? this.sound,
    sahur: sahur ?? this.sahur,
    extras: extras ?? this.extras,
  );
}

/// Reminders besides the prayer times. All use the system notification sound
/// on one channel (`adzan_lainnya`).
enum ExtraReminder {
  tahajjud('Tahajjud', 'Sepertiga malam terakhir'),
  kahfi('Al-Kahfi hari Jumat', 'Setiap Jumat pukul 06.00'),
  puasaSunnah('Puasa Senin–Kamis', 'Minggu dan Rabu malam pukul 20.00'),
  harian('Ayat & hadits hari ini', 'Setiap pagi pukul 07.00');

  const ExtraReminder(this.label, this.description);

  final String label;
  final String description;

  static ExtraReminder? byName(String name) =>
      values.where((e) => e.name == name).firstOrNull;
}

/// Sound of the prayer-time reminders. Android keeps a notification channel's
/// sound for good, so every sound gets its own channel ([channelId]).
///
/// The adzan recording is "Beautiful adhan.ogg" by Adam-synagda (Wikimedia
/// Commons, CC0). Bedug, kentongan and beep are synthesised
/// (`assets_src/sounds/build-sounds.sh`).
enum AdzanSound {
  bawaan('Bunyi notifikasi HP', 'Seperti notifikasi lain di HP ini'),
  adzan(
    'Adzan',
    'Adzan lengkap, 2½ menit',
    resource: 'adzan_penuh',
    preview: 'adzan_takbir',
  ),
  takbir(
    'Takbir',
    'Awal adzan saja, 17 detik',
    resource: 'adzan_takbir',
    preview: 'adzan_takbir',
  ),
  bedug(
    'Bedug',
    'Tabuhan bedug, 5 detik',
    resource: 'adzan_bedug',
    preview: 'adzan_bedug',
  ),
  kentongan(
    'Kentongan',
    'Ketukan kentongan, 3 detik',
    resource: 'adzan_kentongan',
    preview: 'adzan_kentongan',
  ),
  beep(
    'Beep',
    'Dua nada pendek',
    resource: 'adzan_beep',
    preview: 'adzan_beep',
  ),
  senyap('Senyap', 'Hanya tampil, tanpa bunyi');

  const AdzanSound(this.label, this.description, {this.resource, this.preview});

  final String label;
  final String description;

  /// Android raw resource (`res/raw/<resource>.ogg`); null plays the system
  /// sound ([bawaan]) or nothing ([senyap]).
  final String? resource;

  /// Sample under `assets/sounds/<preview>.ogg` for "Dengarkan contoh".
  final String? preview;

  /// Notification channel id. [bawaan] keeps the channel from 1.1.0.
  String get channelId => this == bawaan ? 'adzan' : 'adzan_$name';

  static AdzanSound byName(String? name) =>
      values.where((s) => s.name == name).firstOrNull ?? bawaan;
}

/// One local notification to schedule.
class AdzanReminder {
  const AdzanReminder({
    required this.id,
    required this.at,
    required this.prayer,
    required this.early,
    required this.title,
    required this.body,
    this.renewal = false,
    this.sahur = false,
    this.extra,
    this.sound = AdzanSound.bawaan,
    this.note,
  });

  final int id;
  final DateTime at;

  /// Null for the [renewal] notice and the [sahur] reminder.
  final AdzanPrayer? prayer;

  /// The "10 menit lagi" reminder rather than the prayer time itself.
  final bool early;
  final String title;
  final String body;

  /// The "Buka Muslimku" notice before the plan runs out, see
  /// [AdzanPlan.build].
  final bool renewal;

  /// The reminder before Imsak.
  final bool sahur;

  /// Set for the reminders of [ExtraReminder]; they share one channel.
  final ExtraReminder? extra;

  /// Sound (channel) of this reminder; early and renewal ones stay [AdzanSound.bawaan].
  final AdzanSound sound;

  /// Second line under [body], e.g. the hadith of the day.
  final String? note;
}

/// "Hadits hari ini: judul (Arbain No. n)" for [date], or null when the
/// Arbain list is not saved yet. [titles] maps the Arbain number to its title.
String? adzanHadithLine(
  DateTime date, {
  required Map<int, String> titles,
  required int count,
}) {
  if (titles.isEmpty || count <= 0) return null;
  final number = dailyArbainNumber(date, count: count);
  final title = titles[number];
  if (title == null || title.isEmpty) return null;
  return 'Hadits hari ini: $title (Arbain No. $number)';
}

class AdzanPlan {
  static const leadTime = Duration(minutes: 10);

  /// How long before Imsak the sahur reminder comes.
  static const sahurLead = Duration(minutes: 45);

  /// Days of reminders kept scheduled (Android allows 500 alarms per app).
  static const horizon = Duration(days: 14);

  /// Id of the renewal notice. Prayer ids are yyyymmdd * 10 + 0..9.
  static const renewalId = 1;

  /// How long before the last reminder the renewal notice comes.
  static const renewalLead = Duration(days: 1);

  /// Stable id: yyyymmdd * 10 + prayer * 2 + early.
  static int idFor(DateTime day, AdzanPrayer prayer, {required bool early}) =>
      (day.year * 10000 + day.month * 100 + day.day) * 10 +
      prayer.index * 2 +
      (early ? 1 : 0);

  /// Stable id of the sahur reminder, above every prayer id and still a
  /// 32-bit int: 2 000 000 000 + (yyyymmdd − 20 000 000).
  static int sahurIdFor(DateTime day) => 2000000000 + _dayNumber(day);

  /// Stable id of an extra reminder: its own 10-million block above the
  /// sahur ids (2 010 000 000 … 2 049 999 999, all 32-bit).
  static int extraIdFor(ExtraReminder extra, DateTime day) =>
      2010000000 + extra.index * 10000000 + _dayNumber(day);

  static int _dayNumber(DateTime day) =>
      day.year * 10000 + day.month * 100 + day.day - 20000000;

  /// Minutes after Maghrib at which the last third of the night begins, the
  /// night running from [maghrib] to the next [subuh].
  static DateTime lastThirdOfNight(DateTime maghrib, DateTime nextSubuh) {
    final night = nextSubuh.difference(maghrib).inMinutes;
    return maghrib.add(Duration(minutes: (night * 2 / 3).round()));
  }

  /// Reminders after [now] and before [now] + [horizon], in time order, plus
  /// the renewal notice a day before the last one. [hadithFor] gives the
  /// "Hadits hari ini" line for a date; it goes on the first prayer-time
  /// reminder of that day.
  static List<AdzanReminder> build({
    required List<PrayerSchedule> days,
    required AdzanSettings settings,
    required DateTime now,
    required String city,
    String? Function(DateTime date)? hadithFor,
  }) {
    if (!settings.enabled || settings.prayers.isEmpty) return const [];
    final end = now.add(horizon);
    final out = <AdzanReminder>[];
    for (var i = 0; i < days.length; i++) {
      final day = days[i];
      final date = DateTime.tryParse(day.date);
      if (date == null) continue;
      final tomorrow = i + 1 < days.length ? days[i + 1] : day;
      void extra(ExtraReminder kind, DateTime? at, String title, String body) {
        if (at == null || !at.isAfter(now) || !at.isBefore(end)) return;
        if (!settings.extras.contains(kind)) return;
        out.add(
          AdzanReminder(
            id: extraIdFor(kind, date),
            at: at,
            prayer: null,
            early: false,
            extra: kind,
            title: title,
            body: body,
          ),
        );
      }

      final maghrib = _timeOn(date, day.maghrib);
      final nextSubuh = _timeOn(
        date.add(const Duration(days: 1)),
        tomorrow.subuh,
      );
      if (maghrib != null && nextSubuh != null) {
        final at = lastThirdOfNight(maghrib, nextSubuh);
        extra(
          ExtraReminder.tahajjud,
          at,
          'Waktu tahajjud',
          'Sepertiga malam terakhir mulai ${_hhmm(at)} · Subuh ${tomorrow.subuh}',
        );
      }
      if (date.weekday == DateTime.friday) {
        extra(
          ExtraReminder.kahfi,
          DateTime(date.year, date.month, date.day, 6),
          'Jumat: Surah Al-Kahfi',
          'Sunnah membaca Al-Kahfi di hari Jumat. Buka di Muslimku.',
        );
      }
      if (date.weekday == DateTime.sunday ||
          date.weekday == DateTime.wednesday) {
        final besok = date.weekday == DateTime.sunday ? 'Senin' : 'Kamis';
        extra(
          ExtraReminder.puasaSunnah,
          DateTime(date.year, date.month, date.day, 20),
          'Besok $besok, puasa sunnah?',
          'Niatkan malam ini; Imsak besok ${tomorrow.imsak}, sahur sebelum itu.',
        );
      }
      extra(
        ExtraReminder.harian,
        DateTime(date.year, date.month, date.day, 7),
        'Ayat & hadits hari ini',
        hadithFor?.call(date) ??
            'Buka Muslimku untuk ayat, hadits, dan doa hari ini.',
      );
      if (settings.sahur) {
        final imsak = _timeOn(date, day.imsak);
        final at = imsak?.subtract(sahurLead);
        if (at != null && at.isAfter(now) && at.isBefore(end)) {
          out.add(
            AdzanReminder(
              id: sahurIdFor(date),
              at: at,
              prayer: null,
              early: false,
              sahur: true,
              sound: settings.sound,
              title: 'Waktunya sahur',
              body: 'Imsak pukul ${day.imsak} · $city',
            ),
          );
        }
      }
      String? note = hadithFor?.call(date);
      for (final prayer in AdzanPrayer.values) {
        if (!settings.prayers.contains(prayer)) continue;
        final hhmm = prayer.timeIn(day);
        final at = _timeOn(date, hhmm);
        if (at == null) continue;
        if (at.isAfter(now) && at.isBefore(end)) {
          out.add(
            AdzanReminder(
              id: idFor(date, prayer, early: false),
              at: at,
              prayer: prayer,
              early: false,
              sound: settings.sound,
              title: 'Waktunya ${prayer.label}',
              body: '${prayer.label} $hhmm · $city',
              note: note,
            ),
          );
          note = null;
        }
        final before = at.subtract(leadTime);
        if (settings.remindBefore &&
            before.isAfter(now) &&
            before.isBefore(end)) {
          out.add(
            AdzanReminder(
              id: idFor(date, prayer, early: true),
              at: before,
              prayer: prayer,
              early: true,
              title: '10 menit lagi ${prayer.label}',
              body: '${prayer.label} pukul $hhmm · $city',
            ),
          );
        }
      }
    }
    out.sort((a, b) => a.at.compareTo(b.at));
    final notice = _renewal(out, now);
    if (notice != null) {
      out
        ..add(notice)
        ..sort((a, b) => a.at.compareTo(b.at));
    }
    return out;
  }

  static String _hhmm(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  /// [date] at the "HH:mm" time, or null when the time is missing.
  static DateTime? _timeOn(DateTime date, String hhmm) {
    final parts = hhmm.split(':');
    final h = int.tryParse(parts.first);
    final m = parts.length > 1 ? int.tryParse(parts[1]) : null;
    if (h == null || m == null) return null;
    return DateTime(date.year, date.month, date.day, h, m);
  }

  /// The plan is rebuilt whenever Muslimku opens, so this notice only fires
  /// for someone who has not opened the app for about [horizon]. It asks them
  /// to open it before the reminders stop without a word.
  static AdzanReminder? _renewal(List<AdzanReminder> planned, DateTime now) {
    if (planned.isEmpty) return null;
    final last = planned.last.at;
    var at = last.subtract(renewalLead);
    // In waking hours.
    if (at.hour < 7) {
      at = DateTime(at.year, at.month, at.day, 7);
    } else if (at.hour >= 21) {
      at = DateTime(at.year, at.month, at.day, 20);
    }
    // A plan of a day or two (no schedule saved further ahead) needs no
    // notice: the user has just opened the app.
    if (!at.isAfter(now.add(renewalLead))) return null;
    return AdzanReminder(
      id: renewalId,
      at: at,
      prayer: null,
      early: false,
      renewal: true,
      title: 'Pengingat adzan hampir habis',
      body:
          'Pengingat terpasang sampai ${_dayMonth(last)}. '
          'Buka Muslimku sebentar agar diperpanjang.',
    );
  }

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', //
    'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
  ];

  static String _dayMonth(DateTime d) => '${d.day} ${_months[d.month - 1]}';
}
