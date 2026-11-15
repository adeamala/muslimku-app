import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:muslimku/core/theme/app_colors.dart';
import 'package:muslimku/shared/widgets/diorama/diorama_widgets.dart'
    show FloatingArt;

/// Dusk sky of the tab headers: the home's gradient, shorter, with a warm glow
/// in the lower right and a few stars.
class SenjaStage extends StatelessWidget {
  const SenjaStage({super.key});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.duskTop,
            AppColors.duskHigh,
            AppColors.duskMid,
            AppColors.duskLow,
          ],
          stops: [0, 0.4, 0.76, 1],
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(1.15, 0.95),
            radius: 0.85,
            colors: [
              AppColors.duskSun.withValues(alpha: 0.5),
              AppColors.duskSun.withValues(alpha: 0),
            ],
          ),
        ),
        child: const CustomPaint(
          painter: _StarsPainter(),
          child: SizedBox.expand(),
        ),
      ),
    );
  }
}

class _StarsPainter extends CustomPainter {
  const _StarsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(11);
    final paint = Paint();
    for (var i = 0; i < 22; i++) {
      final x = size.width * (0.38 + random.nextDouble() * 0.6);
      final y = size.height * (0.12 + random.nextDouble() * 0.5);
      final r = [0.6, 0.8, 1.1][random.nextInt(3)];
      paint.color = Colors.white.withValues(
        alpha: [0.5, 0.7, 0.9][random.nextInt(3)],
      );
      canvas.drawCircle(Offset(x, y), r, paint);
    }
  }

  @override
  bool shouldRepaint(_StarsPainter oldDelegate) => false;
}

/// Layout of the Al-Qur'an, Hadits, Asmaul Husna and Doa tabs (design-v2):
/// a 146 px dusk header with the title, the tab's 3D icon floating on the
/// right, and a white sheet (radius 28) that holds [body].
///
/// [body] scrolls on its own; it starts at the top edge of the sheet, so give
/// it about 20 px of top padding.
class SenjaTabScaffold extends StatelessWidget {
  const SenjaTabScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.hero,
    required this.body,
    this.heroWidth = 150,
    this.heroTop = 48,
    this.heroRight = 14,
    this.actions = const [],
  });

  /// Height of the dusk header below the status bar.
  static const headerHeight = 146.0;

  final String title;
  final String subtitle;

  /// Asset path of the 3D icon, e.g. `images/3d/icon_quran.webp`.
  final String hero;
  final double heroWidth;

  /// Distance of the hero from the bottom of the status bar.
  final double heroTop;
  final double heroRight;

  /// Small buttons under the title (optional), e.g. a "Ditandai" shortcut.
  final List<Widget> actions;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: top + headerHeight + 40,
            child: const SenjaStage(),
          ),
          Positioned(
            left: 22,
            top: top + 16,
            right: heroWidth + heroRight - 8,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      title,
                      maxLines: 1,
                      style: const TextStyle(
                        fontSize: 30,
                        height: 1.2,
                        letterSpacing: -0.6,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.38,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.74),
                  ),
                ),
                if (actions.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(mainAxisSize: MainAxisSize.min, children: actions),
                ],
              ],
            ),
          ),
          Positioned(
            top: top + headerHeight,
            left: 0,
            right: 0,
            bottom: 0,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
              child: ColoredBox(color: AppColors.surface, child: body),
            ),
          ),
          Positioned(
            top: top + heroTop,
            right: heroRight,
            child: IgnorePointer(
              child: FloatingArt(
                distance: 4,
                child: Image.asset(
                  hero,
                  width: heroWidth,
                  excludeFromSemantics: true,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
