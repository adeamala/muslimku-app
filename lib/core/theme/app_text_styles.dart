import 'package:flutter/material.dart';
import 'package:muslimku/core/theme/app_colors.dart';

class AppTextStyles {
  AppTextStyles._();

  /// Bundled UI font (see `fonts/` and pubspec.yaml).
  static const String fontFamily = 'PlusJakartaSans';

  /// Bundled Naskh font for every Arabic text (ayat, hadits, doa, Asmaul Husna).
  static const String arabicFontFamily = 'Amiri';

  static TextStyle get _ui => const TextStyle(fontFamily: fontFamily);
  static TextStyle get _arabic => const TextStyle(fontFamily: arabicFontFamily);

  // Headings
  static TextStyle get h1 => _ui.copyWith(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  static TextStyle get h2 => _ui.copyWith(
    fontSize: 28,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static TextStyle get h3 => _ui.copyWith(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static TextStyle get h4 => _ui.copyWith(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static TextStyle get h5 => _ui.copyWith(
    fontSize: 18,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
  );

  static TextStyle get h6 => _ui.copyWith(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
  );

  // Body Text
  static TextStyle get bodyLarge => _ui.copyWith(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
  );

  static TextStyle get bodyMedium => _ui.copyWith(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
  );

  static TextStyle get bodySmall => _ui.copyWith(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
  );

  // Caption & Labels
  static TextStyle get caption => _ui.copyWith(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  static TextStyle get labelLarge => _ui.copyWith(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
  );

  static TextStyle get labelMedium => _ui.copyWith(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
  );

  static TextStyle get labelSmall => _ui.copyWith(
    fontSize: 10,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
  );

  // Special Styles
  static TextStyle get button => _ui.copyWith(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.textLight,
  );

  static TextStyle get overline => _ui.copyWith(
    fontSize: 10,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    letterSpacing: 1.5,
  );

  // Prayer Time Styles
  static TextStyle get prayerTimeTitle => _ui.copyWith(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppColors.textLight,
  );

  static TextStyle get prayerTimeSubtitle => _ui.copyWith(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textLight,
  );

  static TextStyle get prayerTimeCountdown => _ui.copyWith(
    fontSize: 36,
    fontWeight: FontWeight.w700,
    color: AppColors.primary,
  );

  static TextStyle get prayerTimeLabel => _ui.copyWith(
    fontSize: 10,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  static TextStyle get prayerTimeValue => _ui.copyWith(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  // Arabic Text
  static TextStyle get arabicLarge => _arabic.copyWith(
    fontSize: 22,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
    height: 2.0,
  );

  static TextStyle get arabicMedium => _arabic.copyWith(
    fontSize: 18,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
    height: 1.9,
  );

  // Card Title
  static TextStyle get cardTitle => _ui.copyWith(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static TextStyle get cardSubtitle => _ui.copyWith(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );
}
