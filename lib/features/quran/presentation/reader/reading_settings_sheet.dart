import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muslimku/core/theme/app_colors.dart';
import 'package:muslimku/core/theme/app_text_styles.dart';
import 'package:muslimku/core/utils/arabic_text.dart';
import 'package:muslimku/features/quran/domain/tajweed.dart';
import 'package:muslimku/features/quran/presentation/reader/reader_controls.dart';
import 'package:muslimku/features/quran/presentation/reader/tajweed_style.dart';
import 'package:muslimku/features/reading/application/reading_settings_provider.dart';
import 'package:muslimku/shared/widgets/senja/senja.dart';

/// "Tampilan bacaan" (design q4): Arabic size, latin, translation and the
/// reading theme. Every change applies to the reader behind it right away.
Future<void> showReadingSettingsSheet(BuildContext context) {
  return showSenjaSheet<void>(
    context,
    title: 'Tampilan bacaan',
    titleAction: Consumer(
      builder: (context, ref, _) => TextButton(
        onPressed: ref.read(readingSettingsProvider.notifier).reset,
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
    builder: (_) => const ReadingSettingsPanel(),
  );
}

class ReadingSettingsPanel extends ConsumerWidget {
  const ReadingSettingsPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(readingSettingsProvider);
    final notifier = ref.read(readingSettingsProvider.notifier);
    final label = TextStyle(
      fontSize: 13.5,
      fontWeight: FontWeight.w800,
      color: AppColors.ink,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 10),
        Container(
          constraints: const BoxConstraints(minHeight: 86),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.stageBackground,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.lilacLine, width: 1.5),
          ),
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
            Expanded(child: Text('Ukuran huruf Arab', style: label)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.lilac,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${s.arabicSize.round()}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.secondary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            ExcludeSemantics(
              child: Text(
                'A',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.inkMuted,
                ),
              ),
            ),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 6,
                  activeTrackColor: AppColors.secondary,
                  inactiveTrackColor: AppColors.lilac,
                  thumbShape: const _RingThumb(),
                  overlayColor: AppColors.secondary.withValues(alpha: 0.12),
                  overlayShape: const RoundSliderOverlayShape(
                    overlayRadius: 20,
                  ),
                  activeTickMarkColor: Colors.transparent,
                  inactiveTickMarkColor: Colors.transparent,
                  trackShape: const RoundedRectSliderTrackShape(),
                ),
                child: Slider(
                  value: s.arabicSize,
                  min: ReadingSettings.minArabicSize,
                  max: ReadingSettings.maxArabicSize,
                  divisions: 20,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 8,
                  ),
                  semanticFormatterCallback: (v) => 'Ukuran ${v.round()}',
                  onChanged: notifier.setArabicSize,
                ),
              ),
            ),
            ExcludeSemantics(
              child: Text(
                'A',
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  color: AppColors.inkMuted,
                ),
              ),
            ),
          ],
        ),
        ReaderToggleRow(
          label: 'Latin',
          value: s.showLatin,
          onChanged: notifier.setShowLatin,
        ),
        ReaderToggleRow(
          label: 'Terjemahan',
          value: s.showTranslation,
          onChanged: notifier.setShowTranslation,
        ),
        ReaderToggleRow(
          label: 'Tajwid berwarna',
          value: s.tajwid,
          onChanged: notifier.setTajwid,
        ),
        if (s.tajwid) const TajweedLegend(),
        const SizedBox(height: 16),
        Text('Tema bacaan', style: label),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final theme in ReadingTheme.values) ...[
              if (theme != ReadingTheme.values.first) const SizedBox(width: 10),
              Expanded(
                child: _ThemeSwatch(
                  theme: theme,
                  selected: s.theme == theme,
                  onTap: () => notifier.setTheme(theme),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 4),
        ReaderToggleRow(
          label: 'Malam otomatis setelah Maghrib',
          icon: Icons.dark_mode_outlined,
          fontSize: 13.5,
          divider: false,
          value: s.autoNight,
          onChanged: notifier.setAutoNight,
        ),
      ],
    );
  }
}

/// 60 px theme preview tile (design `.sw2`): selected gets a purple ring and
/// a check.
class _ThemeSwatch extends StatelessWidget {
  const _ThemeSwatch({
    required this.theme,
    required this.selected,
    required this.onTap,
  });

  final ReadingTheme theme;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (Gradient? gradient, Color text, bool outlined) = switch (theme) {
      ReadingTheme.terang => (null, AppColors.ink, true),
      ReadingTheme.senja => (
        LinearGradient(
          begin: const Alignment(-0.64, -0.77),
          end: const Alignment(0.64, 0.77),
          colors: [AppColors.lilac, const Color(0xFFD9D2FF)],
        ),
        AppColors.ayahDeep,
        false,
      ),
      ReadingTheme.malam => (
        const LinearGradient(
          begin: Alignment(-0.34, -0.94),
          end: Alignment(0.34, 0.94),
          colors: [AppColors.duskNight, Color(0xFF241A7A)],
        ),
        AppColors.gold,
        false,
      ),
    };
    return Semantics(
      button: true,
      selected: selected,
      label: 'Tema ${theme.label}',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  height: 60,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: gradient == null ? Colors.white : null,
                    gradient: gradient,
                    borderRadius: BorderRadius.circular(16),
                    border: selected
                        ? Border.all(
                            color: AppColors.secondary,
                            width: 2.5,
                            strokeAlign: BorderSide.strokeAlignOutside,
                          )
                        : outlined
                        ? Border.all(color: AppColors.lilacLine, width: 1.5)
                        : null,
                  ),
                  child: Text(
                    'بِسْمِ',
                    textDirection: TextDirection.rtl,
                    textScaler: TextScaler.noScaling,
                    style: TextStyle(
                      fontFamily: AppTextStyles.arabicFontFamily,
                      fontSize: 22,
                      height: 1.4,
                      color: text,
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
                        size: 15,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              theme.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.inkMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// White 26 px thumb with a 3 px purple ring (design `.trk b`).
class _RingThumb extends SliderComponentShape {
  const _RingThumb();

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) =>
      const Size.square(26);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final canvas = context.canvas;
    canvas
      ..drawCircle(
        center + const Offset(0, 3),
        12,
        Paint()
          ..color = AppColors.secondary.withValues(alpha: 0.35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      )
      ..drawCircle(center, 13, Paint()..color = Colors.white)
      ..drawCircle(
        center,
        11.5,
        Paint()
          ..color = AppColors.secondary
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
  }
}

/// "Legenda tajwid": the rule colours, shown under the toggle.
class TajweedLegend extends StatelessWidget {
  const TajweedLegend({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 6, 0, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Legenda tajwid',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: AppColors.inkMuted,
            ),
          ),
          const SizedBox(height: 6),
          // One entry per colour; the three grey rules share a line.
          for (final rule in TajweedRule.values)
            if (rule.color != TajweedRule.hamzatWasl.color ||
                rule == TajweedRule.hamzatWasl)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: rule.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        rule == TajweedRule.hamzatWasl
                            ? 'Hamzah washal, lam syamsiyah, huruf tidak dibaca'
                            : rule.label,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.inkMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          const SizedBox(height: 6),
          Text(
            'Teks tajwid memakai rasm Uthmani dari alquran.cloud; tanpa '
            'internet, surat yang belum tersimpan tampil tanpa warna.',
            style: TextStyle(
              fontSize: 11.5,
              height: 1.4,
              fontWeight: FontWeight.w500,
              color: AppColors.inkMuted,
            ),
          ),
        ],
      ),
    );
  }
}
