import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muslimku/core/theme/app_colors.dart';
import 'package:muslimku/core/theme/app_text_styles.dart';
import 'package:muslimku/core/theme/app_theme_provider.dart';
import 'package:muslimku/core/utils/arabic_text.dart';
import 'package:muslimku/features/prayer/application/prayer_offsets_provider.dart';
import 'package:muslimku/features/prayer/application/prayer_time_provider.dart';
import 'package:muslimku/features/prayer/domain/adzan_plan.dart';
import 'package:muslimku/features/prayer/domain/prayer_offsets.dart';
import 'package:muslimku/features/reading/application/reading_settings_provider.dart';
import 'package:muslimku/shared/widgets/senja/senja.dart';

/// "Tema aplikasi" sheet: follow the phone, light, or dark.
Future<void> showAppThemeSheet(BuildContext context) => showSenjaSheet<void>(
  context,
  title: 'Tema aplikasi',
  builder: (_) => const _AppThemeSheet(),
);

class _AppThemeSheet extends ConsumerWidget {
  const _AppThemeSheet();

  static IconData _icon(AppThemeMode mode) => switch (mode) {
    AppThemeMode.sistem => Icons.phone_android_rounded,
    AppThemeMode.terang => Icons.light_mode_rounded,
    AppThemeMode.gelap => Icons.dark_mode_rounded,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(appThemeProvider);
    return Column(
      children: [
        for (final mode in AppThemeMode.values)
          SenjaChoiceRow(
            icon: _icon(mode),
            title: mode.label,
            subtitle: mode.description,
            selected: mode == current,
            divider: mode != AppThemeMode.values.last,
            onTap: () => ref.read(appThemeProvider.notifier).set(mode),
          ),
      ],
    );
  }
}

/// "Tema bacaan" sheet: Terang / Senja / Malam and night after Maghrib.
Future<void> showReadingThemeSheet(BuildContext context) =>
    showSenjaSheet<void>(
      context,
      title: 'Tema bacaan',
      builder: (_) => const _ThemeSheet(),
    );

/// "Ukuran huruf Arab" sheet with a live preview.
Future<void> showArabicSizeSheet(BuildContext context) => showSenjaSheet<void>(
  context,
  title: 'Ukuran huruf Arab',
  builder: (_) => const _SizeSheet(),
);

/// "Koreksi waktu sholat" sheet: ±15 minutes per prayer.
Future<void> showPrayerOffsetSheet(BuildContext context) =>
    showSenjaSheet<void>(
      context,
      title: 'Koreksi waktu sholat',
      titleAction: Consumer(
        builder: (context, ref, _) => TextButton(
          onPressed: ref.read(prayerOffsetsProvider.notifier).reset,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.secondary,
            minimumSize: const Size(48, 40),
            padding: const EdgeInsets.symmetric(horizontal: 6),
            textStyle: const TextStyle(
              fontFamily: AppTextStyles.fontFamily,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          child: const Text('Atur ulang'),
        ),
      ),
      builder: (_) => const _OffsetSheet(),
    );

class _OffsetSheet extends ConsumerWidget {
  const _OffsetSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offsets = ref.watch(prayerOffsetsProvider);
    final notifier = ref.read(prayerOffsetsProvider.notifier);
    final today = ref.watch(prayerTimeProvider).prayerTime?.jadwal;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Untuk menyamakan dengan masjid setempat. Berlaku di jadwal, '
          'pengingat adzan, dan jadwal sebulan. Imsak ikut Subuh.',
          style: TextStyle(
            fontSize: 13,
            height: 1.4,
            fontWeight: FontWeight.w500,
            color: AppColors.inkMuted,
          ),
        ),
        const SizedBox(height: 6),
        for (final prayer in AdzanPrayer.values)
          _OffsetRow(
            label: prayer.label,
            time: today == null ? null : prayer.timeIn(today),
            minutes: offsets.of(prayer),
            divider: prayer != AdzanPrayer.values.last,
            onChanged: (m) => notifier.set(prayer, m),
          ),
      ],
    );
  }
}

class _OffsetRow extends StatelessWidget {
  const _OffsetRow({
    required this.label,
    required this.time,
    required this.minutes,
    required this.divider,
    required this.onChanged,
  });

  final String label;
  final String? time;
  final int minutes;
  final bool divider;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 56),
      decoration: BoxDecoration(
        border: divider
            ? Border(bottom: BorderSide(color: AppColors.lilacLine))
            : null,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
                if (time != null)
                  Text(
                    'Hari ini $time',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.inkMuted,
                    ),
                  ),
              ],
            ),
          ),
          SenjaIconButton(
            icon: Icons.remove_rounded,
            tooltip: '$label 1 menit lebih cepat',
            style: SenjaIconStyle.lilac,
            size: 34,
            iconSize: 20,
            onPressed: minutes <= -PrayerOffsets.limit
                ? null
                : () => onChanged(minutes - 1),
          ),
          SizedBox(
            width: 44,
            child: Text(
              PrayerOffsets.signed(minutes),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: minutes == 0 ? AppColors.inkMuted : AppColors.secondary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          SenjaIconButton(
            icon: Icons.add_rounded,
            tooltip: '$label 1 menit lebih lambat',
            style: SenjaIconStyle.lilac,
            size: 34,
            iconSize: 20,
            onPressed: minutes >= PrayerOffsets.limit
                ? null
                : () => onChanged(minutes + 1),
          ),
        ],
      ),
    );
  }
}

class _ThemeSheet extends ConsumerWidget {
  const _ThemeSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(readingSettingsProvider);
    final notifier = ref.read(readingSettingsProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Dipakai di halaman baca Al-Qur\'an, hadits, dan doa.',
          style: TextStyle(
            fontSize: 13,
            height: 1.4,
            fontWeight: FontWeight.w500,
            color: AppColors.inkMuted,
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            for (final theme in ReadingTheme.values) ...[
              if (theme != ReadingTheme.terang) const SizedBox(width: 10),
              Expanded(
                child: ThemeSwatch(
                  theme: theme,
                  selected: s.theme == theme,
                  onTap: () => notifier.setTheme(theme),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),
        SenjaToggleRow(
          icon: Icons.dark_mode_outlined,
          label: 'Malam otomatis setelah Maghrib',
          value: s.autoNight,
          onChanged: notifier.setAutoNight,
          divider: false,
        ),
      ],
    );
  }
}

/// Small preview of a [ReadingTheme] (design q4 `.sw2`).
class ThemeSwatch extends StatelessWidget {
  const ThemeSwatch({
    super.key,
    required this.theme,
    required this.selected,
    required this.onTap,
  });

  final ReadingTheme theme;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = ReadingPalette.of(theme);
    return Semantics(
      button: true,
      selected: selected,
      label: 'Tema ${theme.label}',
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  height: 60,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [palette.background, palette.backgroundEnd],
                    ),
                    border: Border.all(
                      color: selected
                          ? AppColors.secondary
                          : AppColors.lilacLine,
                      width: selected ? 2.5 : 1.5,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: ExcludeSemantics(
                    child: ArabicText(
                      'بِسْمِ',
                      size: 22,
                      color: palette.arabic,
                      align: TextAlign.center,
                      height: 1.4,
                    ),
                  ),
                ),
                if (selected)
                  Positioned(
                    right: -6,
                    top: -6,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: const BoxDecoration(
                        color: AppColors.secondary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        size: 14,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              theme.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: selected ? AppColors.ink : AppColors.inkMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SizeSheet extends ConsumerWidget {
  const _SizeSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(readingSettingsProvider);
    final notifier = ref.read(readingSettingsProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          constraints: const BoxConstraints(minHeight: 86),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.stageBackground,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.lilacLine, width: 1.5),
          ),
          alignment: Alignment.center,
          child: ArabicText(
            bismillah,
            size: s.arabicSize,
            align: TextAlign.center,
            height: 1.7,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Text(
                'Ukuran',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
            ),
            SenjaTag('${s.arabicSize.round()}'),
          ],
        ),
        Row(
          children: [
            Text(
              'A',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppColors.inkMuted,
              ),
            ),
            Expanded(
              child: Slider(
                value: s.arabicSize,
                min: ReadingSettings.minArabicSize,
                max: ReadingSettings.maxArabicSize,
                divisions: 20,
                label: '${s.arabicSize.round()}',
                activeColor: AppColors.secondary,
                inactiveColor: AppColors.lilac,
                onChanged: notifier.setArabicSize,
              ),
            ),
            Text(
              'A',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w800,
                color: AppColors.inkMuted,
              ),
            ),
          ],
        ),
        Text(
          'Ukuran huruf di pengaturan HP juga ikut dipakai (sampai 130%).',
          style: TextStyle(
            fontSize: 12,
            height: 1.4,
            fontWeight: FontWeight.w600,
            color: AppColors.inkMuted,
          ),
        ),
      ],
    );
  }
}
