import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muslimku/app/splash_screen.dart';
import 'package:muslimku/core/theme/app_colors.dart';
import 'package:muslimku/core/theme/app_theme.dart';
import 'package:muslimku/core/theme/app_theme_provider.dart';

/// The root widget: theme (light, dark or following the phone), the capped
/// text scale, and the splash as the first route.
class MuslimkuApp extends ConsumerStatefulWidget {
  const MuslimkuApp({super.key});

  @override
  ConsumerState<MuslimkuApp> createState() => _MuslimkuAppState();
}

class _MuslimkuAppState extends ConsumerState<MuslimkuApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(appThemeProvider);
    final platform =
        MediaQuery.maybePlatformBrightnessOf(context) ??
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    applyAppDarkMode(mode.isDark(platform));
    return MaterialApp(
      title: 'Muslimku',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: mode.themeMode,
      home: const SplashScreen(),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: appTextScaler(MediaQuery.textScalerOf(context)),
          ),
          child: child!,
        );
      },
    );
  }
}

/// Flips the Senja palette. Screens read `AppColors.ink` etc. straight in
/// their build methods, and widgets whose parents hand them the same instance
/// would keep stale colours, so a change reassembles the whole tree (state,
/// navigation and scroll positions survive; only the pixels change).
void applyAppDarkMode(bool dark) {
  if (AppColors.dark == dark) return;
  AppColors.dark = dark;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    WidgetsBinding.instance.reassembleApplication();
  });
}

/// Follows the phone's font size setting, capped at 130 % so the layouts hold
/// (it used to be ignored completely). Smaller settings keep 100 %.
TextScaler appTextScaler(TextScaler system) =>
    system.clamp(minScaleFactor: 1.0, maxScaleFactor: 1.3);
