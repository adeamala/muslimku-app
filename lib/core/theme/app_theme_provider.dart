import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muslimku/core/state/mounted_flag.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tema aplikasi: follow the phone, always light, or always dark.
enum AppThemeMode {
  sistem('Ikuti HP', 'Gelap bila HP dalam mode gelap'),
  terang('Terang', 'Latar lilac, teks tinta'),
  gelap('Gelap', 'Latar malam, teks krem');

  const AppThemeMode(this.label, this.description);

  final String label;
  final String description;

  ThemeMode get themeMode => switch (this) {
    AppThemeMode.sistem => ThemeMode.system,
    AppThemeMode.terang => ThemeMode.light,
    AppThemeMode.gelap => ThemeMode.dark,
  };

  /// Whether the app is dark under this mode for [platformBrightness].
  bool isDark(Brightness platformBrightness) => switch (this) {
    AppThemeMode.sistem => platformBrightness == Brightness.dark,
    AppThemeMode.terang => false,
    AppThemeMode.gelap => true,
  };

  static AppThemeMode byName(String? name) =>
      values.where((m) => m.name == name).firstOrNull ?? AppThemeMode.sistem;
}

final appThemeProvider = NotifierProvider<AppThemeNotifier, AppThemeMode>(
  AppThemeNotifier.new,
);

class AppThemeNotifier extends Notifier<AppThemeMode> {
  @override
  AppThemeMode build() {
    _touched = false;
    ready = _load(MountedFlag(ref));
    return AppThemeMode.sistem;
  }

  static const key = 'app_theme';

  late Future<void> ready;
  bool _touched = false;

  Future<void> _load(MountedFlag alive) async {
    final prefs = await SharedPreferences.getInstance();
    if (_touched || !alive.mounted) return;
    state = AppThemeMode.byName(prefs.getString(key));
  }

  Future<void> set(AppThemeMode mode) async {
    _touched = true;
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, mode.name);
  }
}
