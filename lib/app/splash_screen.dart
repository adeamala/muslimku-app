import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muslimku/app/shell/bottom_navigation_bar.dart';
import 'package:muslimku/app/shell/home_screen.dart';
import 'package:muslimku/core/theme/app_colors.dart';
import 'package:muslimku/core/theme/app_text_styles.dart';
import 'package:muslimku/features/onboarding/presentation/onboarding_screen.dart';

/// Brand screen shown while the home artwork is decoded (0.5–1.5 s). It
/// repeats the system splash exactly (M mark on purple, same size and place)
/// and only adds the wordmark, so opening the app shows one splash, not two.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  /// The launcher icon's foreground (assets_src/brand), 864 px = 288 dp @3x.
  static const markAsset = 'images/splash_mark.png';

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  static const minShow = Duration(milliseconds: 500);
  static const maxWait = Duration(milliseconds: 1500);

  /// Decoded up front so the home stage and the bottom bar never pop in.
  static final homeImages = [
    'images/3d/diorama_senja.webp',
    'images/3d/moon.webp',
    for (final item in CustomBottomNavigationBar.items) item.$2,
    'images/3d/icon_kiblat.webp',
    'images/3d/icon_tasbih.webp',
  ];

  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _openHome();
    }
  }

  Future<void> _openHome() async {
    final precache =
        Future.wait<void>([
              for (final path in homeImages)
                precacheImage(AssetImage(path), context),
            ])
            .timeout(maxWait, onTimeout: () => const [])
            .catchError((_) => const <void>[]);
    await Future.wait<void>([Future<void>.delayed(minShow), precache]);
    final onboarding = await needsOnboarding();
    if (!mounted) return;
    unawaited(
      Navigator.of(context).pushReplacement(
        PageRouteBuilder<void>(
          transitionDuration: const Duration(milliseconds: 280),
          pageBuilder: (context, animation, secondaryAnimation) => onboarding
              ? OnboardingScreen(
                  onDone: () => Navigator.of(context).pushReplacement(
                    MaterialPageRoute<void>(builder: (_) => const HomeScreen()),
                  ),
                )
              : const HomeScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      // Same purple as the system splash (android res/values*/colors.xml).
      backgroundColor: AppColors.secondary,
      body: Stack(
        children: [
          // 288 x 288 like the Android 12+ system splash icon (an icon with no
          // splash background colour) and launch_background: no jump.
          Center(
            child: Image.asset(
              SplashScreen.markAsset,
              width: 288,
              height: 288,
              semanticLabel: 'Muslimku',
              errorBuilder: (context, error, stackTrace) =>
                  const SizedBox(width: 288, height: 288),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 56 + bottom,
            child: const _Wordmark(),
          ),
        ],
      ),
    );
  }
}

/// "Muslimku" under the mark. It fades in so it reads as the next step of
/// the system splash rather than a second screen.
class _Wordmark extends StatefulWidget {
  const _Wordmark();

  @override
  State<_Wordmark> createState() => _WordmarkState();
}

class _WordmarkState extends State<_Wordmark>
    with SingleTickerProviderStateMixin {
  late final _fade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _fade.value = 1;
    } else if (!_fade.isAnimating && _fade.value == 0) {
      _fade.forward();
    }
  }

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: CurvedAnimation(parent: _fade, curve: Curves.easeOut),
      child: const ExcludeSemantics(
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(text: 'Muslim'),
              TextSpan(
                text: 'ku',
                style: TextStyle(color: AppColors.primary),
              ),
            ],
          ),
          textAlign: TextAlign.center,
          textScaler: TextScaler.noScaling,
          style: TextStyle(
            fontFamily: AppTextStyles.fontFamily,
            fontSize: 26,
            letterSpacing: -0.4,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
