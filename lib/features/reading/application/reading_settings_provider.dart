import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muslimku/core/state/mounted_flag.dart';
import 'package:muslimku/core/theme/app_colors.dart';
import 'package:muslimku/core/time/clock_provider.dart';
import 'package:muslimku/features/prayer/application/prayer_time_provider.dart';
import 'package:muslimku/features/prayer/domain/prayer_time_model.dart';
import 'package:muslimku/features/quran/domain/reciters.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Look of the reading pages (Al-Qur'an, hadits and doa detail).
enum ReadingTheme { terang, senja, malam }

extension ReadingThemeLabel on ReadingTheme {
  String get label => switch (this) {
    ReadingTheme.terang => 'Terang',
    ReadingTheme.senja => 'Senja',
    ReadingTheme.malam => 'Malam',
  };
}

class ReadingSettings {
  const ReadingSettings({
    this.arabicSize = defaultArabicSize,
    this.showLatin = true,
    this.showTranslation = true,
    this.theme = ReadingTheme.terang,
    this.autoNight = true,
    this.reciter = Reciter.alafasy,
    this.tajwid = false,
  });

  static const minArabicSize = 20.0;
  static const maxArabicSize = 40.0;
  static const defaultArabicSize = 28.0;

  /// Arabic font size in logical pixels (20–40).
  final double arabicSize;
  final bool showLatin;
  final bool showTranslation;
  final ReadingTheme theme;

  /// Use [ReadingTheme.malam] from Maghrib until Subuh.
  final bool autoNight;

  /// Qari of the murottal.
  final Reciter reciter;

  /// Colour the tajweed rules (alquran.cloud markup, Uthmani text).
  final bool tajwid;

  ReadingSettings copyWith({
    double? arabicSize,
    bool? showLatin,
    bool? showTranslation,
    ReadingTheme? theme,
    bool? autoNight,
    Reciter? reciter,
    bool? tajwid,
  }) => ReadingSettings(
    arabicSize: arabicSize ?? this.arabicSize,
    showLatin: showLatin ?? this.showLatin,
    showTranslation: showTranslation ?? this.showTranslation,
    theme: theme ?? this.theme,
    autoNight: autoNight ?? this.autoNight,
    tajwid: tajwid ?? this.tajwid,
    reciter: reciter ?? this.reciter,
  );
}

final readingSettingsProvider =
    NotifierProvider<ReadingSettingsNotifier, ReadingSettings>(
      ReadingSettingsNotifier.new,
    );

class ReadingSettingsNotifier extends Notifier<ReadingSettings> {
  @override
  ReadingSettings build() {
    _touched = false;
    ready = _load(MountedFlag(ref));
    return const ReadingSettings();
  }

  static const sizeKey = 'reading_arabic_size';
  static const latinKey = 'reading_show_latin';
  static const translationKey = 'reading_show_translation';
  static const themeKey = 'reading_theme';
  static const autoNightKey = 'reading_auto_night';
  static const reciterKey = 'reading_reciter';
  static const tajwidKey = 'reading_tajwid';

  late Future<void> ready;
  bool _touched = false;

  Future<void> _load(MountedFlag alive) async {
    final prefs = await SharedPreferences.getInstance();
    if (_touched || !alive.mounted) return;
    final themeName = prefs.getString(themeKey);
    state = ReadingSettings(
      arabicSize:
          (prefs.getDouble(sizeKey) ?? ReadingSettings.defaultArabicSize).clamp(
            ReadingSettings.minArabicSize,
            ReadingSettings.maxArabicSize,
          ),
      showLatin: prefs.getBool(latinKey) ?? true,
      showTranslation: prefs.getBool(translationKey) ?? true,
      theme:
          ReadingTheme.values.where((t) => t.name == themeName).firstOrNull ??
          ReadingTheme.terang,
      autoNight: prefs.getBool(autoNightKey) ?? true,
      reciter: Reciter.byName(prefs.getString(reciterKey)),
      tajwid: prefs.getBool(tajwidKey) ?? false,
    );
  }

  void setArabicSize(double size) => _update(
    state.copyWith(
      arabicSize: size
          .clamp(ReadingSettings.minArabicSize, ReadingSettings.maxArabicSize)
          .roundToDouble(),
    ),
  );

  void setShowLatin(bool value) => _update(state.copyWith(showLatin: value));
  void setShowTranslation(bool value) =>
      _update(state.copyWith(showTranslation: value));
  void setTheme(ReadingTheme theme) => _update(state.copyWith(theme: theme));
  void setAutoNight(bool value) => _update(state.copyWith(autoNight: value));
  void setReciter(Reciter reciter) => _update(state.copyWith(reciter: reciter));
  void setTajwid(bool value) => _update(state.copyWith(tajwid: value));

  void reset() => _update(const ReadingSettings());

  void _update(ReadingSettings next) {
    _touched = true;
    state = next;
    _save(next);
  }

  Future<void> _save(ReadingSettings s) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(sizeKey, s.arabicSize);
    await prefs.setBool(latinKey, s.showLatin);
    await prefs.setBool(translationKey, s.showTranslation);
    await prefs.setString(themeKey, s.theme.name);
    await prefs.setBool(autoNightKey, s.autoNight);
    await prefs.setString(reciterKey, s.reciter.name);
    await prefs.setBool(tajwidKey, s.tajwid);
  }
}

DateTime? _at(DateTime day, String hhmm) {
  final parts = hhmm.split(':');
  if (parts.length < 2) return null;
  final h = int.tryParse(parts[0].trim());
  final m = int.tryParse(parts[1].trim());
  if (h == null || m == null) return null;
  return DateTime(day.year, day.month, day.day, h, m);
}

/// Between today's Maghrib and Subuh, or 18:00–04:30 without a schedule.
bool isNightTime(DateTime now, PrayerSchedule? schedule) {
  final maghrib = schedule == null ? null : _at(now, schedule.maghrib);
  final subuh = schedule == null ? null : _at(now, schedule.subuh);
  final start = maghrib ?? DateTime(now.year, now.month, now.day, 18);
  final end = subuh ?? DateTime(now.year, now.month, now.day, 4, 30);
  return !now.isBefore(start) || now.isBefore(end);
}

/// The theme to draw now: the user's choice, or Malam at night when
/// "Malam otomatis setelah Maghrib" is on.
final activeReadingThemeProvider = Provider<ReadingTheme>((ref) {
  final settings = ref.watch(readingSettingsProvider);
  if (!settings.autoNight) return settings.theme;
  final now = ref.watch(clockProvider).valueOrNull ?? DateTime.now();
  final schedule = ref.watch(prayerTimeProvider).prayerTime?.jadwal;
  return isNightTime(now, schedule) ? ReadingTheme.malam : settings.theme;
});

/// Colours of a [ReadingTheme] (see design-v2 screens q3, q4, q5).
class ReadingPalette {
  const ReadingPalette({
    required this.background,
    required this.backgroundEnd,
    required this.surface,
    required this.line,
    required this.arabic,
    required this.latin,
    required this.translation,
    required this.title,
    required this.muted,
    required this.accent,
    required this.onAccent,
    required this.highlight,
    required this.isDark,
  });

  final Color background;

  /// Bottom of the background gradient (same as [background] when flat).
  final Color backgroundEnd;

  /// Cards and banners on top of the background.
  final Color surface;
  final Color line;
  final Color arabic;
  final Color latin;
  final Color translation;
  final Color title;
  final Color muted;

  /// Buttons, badges and the playing ayah.
  final Color accent;
  final Color onAccent;

  /// Background of the ayah being played.
  final Color highlight;
  final bool isDark;

  static const terang = ReadingPalette(
    background: Colors.white,
    backgroundEnd: Colors.white,
    surface: Color(0xFFF7F5FF),
    line: Color(0xFFE4E0F7),
    arabic: Color(0xFF16123A),
    latin: AppColors.secondary,
    translation: Color(0xFF2C2754),
    title: Color(0xFF16123A),
    muted: Color(0xFF5E5980),
    accent: AppColors.secondary,
    onAccent: Colors.white,
    highlight: Color(0xFFF7F5FF),
    isDark: false,
  );

  static const senja = ReadingPalette(
    background: Color(0xFFEEEBFF),
    backgroundEnd: Color(0xFFE2DCFF),
    surface: Color(0xFFF7F5FF),
    line: Color(0xFFDAD4FF),
    arabic: AppColors.ayahDeep,
    latin: AppColors.secondary,
    translation: Color(0xFF2C2754),
    title: Color(0xFF16123A),
    muted: Color(0xFF5E5980),
    accent: AppColors.secondary,
    onAccent: Colors.white,
    highlight: Color(0xFFF7F5FF),
    isDark: false,
  );

  static const malam = ReadingPalette(
    background: AppColors.duskNight,
    backgroundEnd: Color(0xFF110A48),
    surface: AppColors.nightSurface,
    line: Color(0x29F2B33D),
    arabic: AppColors.nightCream,
    latin: AppColors.gold,
    translation: AppColors.nightMuted,
    title: AppColors.nightCream,
    muted: Color(0xFFA9A3D6),
    accent: AppColors.gold,
    onAccent: AppColors.duskNight,
    highlight: Color(0x1FF2B33D),
    isDark: true,
  );

  static ReadingPalette of(ReadingTheme theme) => switch (theme) {
    ReadingTheme.terang => terang,
    ReadingTheme.senja => senja,
    ReadingTheme.malam => malam,
  };
}
