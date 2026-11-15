import 'package:flutter/material.dart';

/// The Diorama Senja palette. The surface and ink tokens follow
/// [AppColors.dark]; everything else (purple, lime, gold, dusk) is fixed.
/// `main.dart` flips [dark] and rebuilds the whole tree, so screens may keep
/// reading `AppColors.ink` in build methods, just never inside a `const`.
class AppColors {
  AppColors._();

  /// Dark mode on. Set by the app theme provider before the tree rebuilds.
  static bool dark = false;

  static const Color primary = Color(0xFFD2F801);
  static const Color secondary = Color(0xFF5A45FE);
  static const Color gray = Color(0xFF737373);
  static const Color bgGray = Color(0xFFD0D0D0);
  static const Color bgSecondary = Color(0xFF9A9A9A);
  static const Color transparent = Colors.transparent;
  static const Color textLight = Colors.white;

  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFF9800);
  static const Color error = Color(0xFFF44336);
  static const Color info = Color(0xFF2196F3);

  // Diorama Senja (home stage, qibla and tasbih screens)
  static const Color duskTop = Color(0xFF170F5C);
  static const Color duskHigh = Color(0xFF2D1FA6);
  static const Color duskMid = Color(0xFF4F3BEF);
  static const Color duskLow = Color(0xFF7C69FF);
  static const Color duskHorizon = Color(0xFFB7A6FF);
  static const Color duskSun = Color(0xFFFFAA82);
  static const Color duskNight = Color(0xFF0F0846);
  static const Color ayahDeep = Color(0xFF2A1C9E);
  static const Color gold = Color(0xFFF2B33D);

  // Tab redesign ("Diorama Senja" for Al-Qur'an, Hadits, Asmaul Husna, Doa).
  static const Color featureTop = Color(0xFF6B57FF);
  static const Color nightCream = Color(0xFFF6EEDC);
  static const Color nightMuted = Color(0xFFB9B3E0);
  static const Color nightSurface = Color(0xFF170F5C);
  static const Color offlineAccent = Color(0xFFC2562A);

  // ---- Tokens that follow the mode ------------------------------------

  /// Card, sheet and chip surface: white by day, deep navy-purple by night.
  static Color get surface => dark ? const Color(0xFF1B1550) : Colors.white;
  static Color get white => surface;
  static Color get bgWhite => surface;

  /// Page background behind the cards.
  static Color get stageBackground =>
      dark ? const Color(0xFF0F0A3A) : const Color(0xFFF7F5FF);

  /// Main text.
  static Color get ink =>
      dark ? const Color(0xFFF3F0FF) : const Color(0xFF16123A);

  /// Secondary text.
  static Color get inkMuted =>
      dark ? const Color(0xFFB5AEDC) : const Color(0xFF5E5980);

  /// Body copy in long reads.
  static Color get bodyText =>
      dark ? const Color(0xFFE2DDF6) : const Color(0xFF2C2754);

  static Color get textPrimary => ink;
  static Color get textSecondary => dark ? inkMuted : gray;
  static Color get black =>
      dark ? const Color(0xFFF3F0FF) : const Color(0xFF191919);

  /// Soft lilac fill: icon tiles, inactive chips, skeletons.
  static Color get lilac =>
      dark ? const Color(0xFF2A2366) : const Color(0xFFEEEBFF);
  static Color get lilacShadow =>
      dark ? const Color(0xFF0B0730) : const Color(0xFFDAD4FF);
  static Color get lilacLine =>
      dark ? const Color(0xFF352E72) : const Color(0xFFE4E0F7);
  static Color get outline =>
      dark ? const Color(0xFF352E72) : const Color(0xFFF1F1F1);

  static Color get goldSoft =>
      dark ? const Color(0xFF3A2E1A) : const Color(0xFFFFF5E1);
  static Color get offlineSurface =>
      dark ? const Color(0xFF3A2418) : const Color(0xFFFFF3EC);
  static Color get offlineLine =>
      dark ? const Color(0xFF5A3A28) : const Color(0xFFFFD9C7);
  static Color get offlineIconBg =>
      dark ? const Color(0xFF4A2E20) : const Color(0xFFFFE1D3);

  static MaterialColor createMaterialColor(Color color) {
    final List<double> strengths = <double>[.05];
    final Map<int, Color> swatch = {};
    final int r = (color.r * 255.0).round() & 0xff;
    final int g = (color.g * 255.0).round() & 0xff;
    final int b = (color.b * 255.0).round() & 0xff;

    for (int i = 1; i < 10; i++) {
      strengths.add(0.1 * i);
    }

    for (final double strength in strengths) {
      final double ds = 0.5 - strength;
      swatch[(strength * 1000).round()] = Color.fromRGBO(
        r + ((ds < 0 ? r : (255 - r)) * ds).round(),
        g + ((ds < 0 ? g : (255 - g)) * ds).round(),
        b + ((ds < 0 ? b : (255 - b)) * ds).round(),
        1,
      );
    }

    return MaterialColor(color.toARGB32(), swatch);
  }
}
