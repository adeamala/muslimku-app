import 'package:flutter/material.dart';
import 'package:muslimku/core/theme/app_colors.dart';
import 'package:muslimku/features/quran/domain/quran_models.dart';
import 'package:muslimku/features/quran/presentation/reader/next_surah_button.dart';
import 'package:muslimku/features/quran/presentation/reader/reader_header.dart';
import 'package:muslimku/features/reading/application/reading_settings_provider.dart';
import 'package:muslimku/shared/widgets/senja/senja.dart';

/// Page background of the reader for [p] (flat, lilac or night gradient).
Gradient readerPageGradient(ReadingPalette p) => LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: p.isDark
      ? [p.background, p.surface, p.backgroundEnd]
      : [p.background, p.backgroundEnd],
  stops: p.isDark ? const [0, 0.48, 1] : null,
);

/// Reader app bar: surah name, "Juz 22 · Hal. 440", "Aa" and "Lompat ke ayat".
class ReaderAppBar extends StatelessWidget {
  const ReaderAppBar({
    super.key,
    required this.title,
    required this.subtitle,
    required this.palette,
    required this.onSettings,
    required this.onJump,
    this.onMushaf,
    this.opacity = 1,
  });

  final String title;
  final String subtitle;
  final ReadingPalette palette;
  final VoidCallback onSettings;
  final VoidCallback onJump;

  /// Opens the mushaf at the current page.
  final VoidCallback? onMushaf;

  /// Background opacity; the night bar starts transparent over the arch.
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final night = palette.isDark;
    return SenjaDetailAppBar(
      title: title,
      subtitle: subtitle,
      foreground: palette.title,
      subtitleColor: night
          ? AppColors.gold.withValues(alpha: 0.85)
          : palette.muted,
      background: palette.background.withValues(alpha: opacity),
      dark: night,
      actions: [
        if (onMushaf != null)
          SenjaIconButton(
            icon: Icons.auto_stories_rounded,
            tooltip: 'Buka halaman mushaf',
            style: night ? SenjaIconStyle.goldOutline : SenjaIconStyle.plain,
            color: night ? null : palette.title,
            onPressed: onMushaf,
          ),
        SenjaIconButton(
          tooltip: 'Tampilan bacaan',
          style: night ? SenjaIconStyle.goldOutline : SenjaIconStyle.lilac,
          onPressed: onSettings,
          child: const Text('Aa', style: TextStyle(letterSpacing: -0.3)),
        ),
        SenjaIconButton(
          icon: Icons.format_list_numbered_rounded,
          tooltip: 'Lompat ke ayat',
          // Filled at night like the mock's gold button; it also hides the
          // top of the right lantern hanging behind it.
          style: night ? SenjaIconStyle.goldFilled : SenjaIconStyle.plain,
          color: night ? null : palette.title,
          onPressed: onJump,
        ),
      ],
    );
  }
}

/// First item of the reader list: the purple banner (light themes) or the
/// Mihrab Emas header (night), then the bismillah.
class ReaderListHeader extends StatelessWidget {
  const ReaderListHeader({
    super.key,
    required this.surah,
    required this.palette,
    required this.barHeight,
    required this.autoNight,
    required this.playing,
    required this.onPlay,
    required this.onTafsir,
    this.onMurottal,
  });

  final Surah surah;
  final ReadingPalette palette;

  /// Height of the app bar including the status bar.
  final double barHeight;

  /// The night theme was switched on by "Malam otomatis setelah Maghrib".
  final bool autoNight;
  final bool playing;
  final VoidCallback onPlay;
  final VoidCallback onTafsir;
  final VoidCallback? onMurottal;

  @override
  Widget build(BuildContext context) {
    if (palette.isDark) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          NightHeader(
            surah: surah,
            topInset: barHeight - 56,
            autoNight: autoNight,
          ),
          if (surah.showsBismillah)
            const ReaderBismillah(color: AppColors.gold, size: 24, top: 0),
        ],
      );
    }
    return Padding(
      padding: EdgeInsets.only(top: barHeight + 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ReaderBanner(
              surah: surah,
              playing: playing,
              onPlay: onPlay,
              onTafsir: onTafsir,
              onMurottal: onMurottal,
            ),
          ),
          if (surah.showsBismillah) ReaderBismillah(color: palette.arabic),
        ],
      ),
    );
  }
}

/// Last item of the reader list: the next surah and room for the player.
class ReaderListFooter extends StatelessWidget {
  const ReaderListFooter({
    super.key,
    required this.next,
    required this.bottom,
    required this.onNext,
  });

  /// Null after An-Nas.
  final Surah? next;
  final double bottom;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final surah = next;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 24, 20, 28 + bottom),
      child: surah == null
          ? const SizedBox(height: 8)
          : NextSurahButton(name: surah.name, onTap: onNext),
    );
  }
}

/// Fade behind the mini player so the text does not run into it.
class PlayerFade extends StatelessWidget {
  const PlayerFade({super.key, required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [color, color, color.withValues(alpha: 0)],
            stops: const [0, 0.5, 1],
          ),
        ),
      ),
    );
  }
}
