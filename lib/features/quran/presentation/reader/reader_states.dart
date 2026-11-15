import 'package:flutter/material.dart';

import 'package:muslimku/core/theme/app_colors.dart';
import 'package:muslimku/features/quran/domain/quran_models.dart';
import 'package:muslimku/features/reading/application/reading_settings_provider.dart';
import 'package:muslimku/shared/widgets/senja/senja.dart';

/// App bar of the reader states in the colours of [palette].
SenjaDetailAppBar readerStateBar(
  ReadingPalette palette, {
  required String title,
  String? subtitle,
}) => SenjaDetailAppBar(
  title: title,
  subtitle: subtitle,
  foreground: palette.title,
  subtitleColor: palette.isDark
      ? AppColors.gold.withValues(alpha: 0.85)
      : palette.muted,
  background: palette.background,
  dark: palette.isDark,
);

/// Shimmer while the surah loads.
class ReaderLoading extends StatelessWidget {
  const ReaderLoading({super.key, required this.palette, required this.title});

  final ReadingPalette palette;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: palette.background,
      body: Column(
        children: [
          readerStateBar(palette, title: title),
          Expanded(
            child: Opacity(
              opacity: palette.isDark ? 0.2 : 1,
              child: const SenjaSkeletonList(
                rows: 7,
                padding: EdgeInsets.fromLTRB(20, 12, 20, 0),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Surat ini belum tersimpan" (design o2): offline and never opened before.
class ReaderNotSaved extends StatelessWidget {
  const ReaderNotSaved({
    super.key,
    required this.number,
    required this.palette,
    required this.onRetry,
    this.surah,
  });

  final int number;

  /// Null when even the surah list could not be loaded.
  final Surah? surah;
  final ReadingPalette palette;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final s = surah;
    return Scaffold(
      backgroundColor: palette.background,
      body: Column(
        children: [
          readerStateBar(
            palette,
            title: s?.name ?? 'Surat $number',
            subtitle: s == null ? null : '${s.meaning} · ${s.verseCount} ayat',
          ),
          Expanded(
            child: SenjaEmptyState(
              image: 'images/3d/icon_quran.webp',
              badgeIcon: Icons.wifi_off_rounded,
              title: 'Surat ini belum tersimpan',
              message:
                  'Buka sekali saat ada internet. Setelah itu '
                  // Keep "Ali 'Imran" on one line.
                  '${s?.name.replaceAll(' ', '\u00A0') ?? 'surat ini'} bisa '
                  'dibaca kapan saja, '
                  'tanpa kuota.',
              primaryLabel: 'Coba lagi',
              onPrimary: onRetry,
              secondaryLabel: 'Buka surat yang tersimpan',
              onSecondary: () => Navigator.maybePop(context),
              tip: 'Unduh semua surat di Pengaturan › Data offline',
              dark: palette.isDark,
            ),
          ),
        ],
      ),
    );
  }
}
