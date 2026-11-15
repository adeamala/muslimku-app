import 'package:flutter/material.dart';

import 'package:muslimku/core/theme/app_colors.dart';

/// Dusk sky of the "Diorama Senja" design: purple gradient, warm glow at the
/// horizon and a few stars. Used behind the home stage and the qibla screen.
class DuskSky extends StatelessWidget {
  const DuskSky({
    super.key,
    this.child,
    this.glowAlignment = const Alignment(0.6, 1),
  });

  final Widget? child;
  final Alignment glowAlignment;

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
            AppColors.duskHorizon,
          ],
          stops: [0, 0.34, 0.58, 0.78, 1],
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: glowAlignment,
            radius: 0.95,
            colors: [
              AppColors.duskSun.withValues(alpha: 0.8),
              AppColors.duskSun.withValues(alpha: 0),
            ],
          ),
        ),
        child: CustomPaint(
          painter: const _StarsPainter(),
          child: SizedBox.expand(child: child),
        ),
      ),
    );
  }
}

class _StarsPainter extends CustomPainter {
  const _StarsPainter();

  // (x, y) as fractions of the width and of the top 40 % of the height, plus opacity.
  static const _stars = [
    [0.49, 0.12, 0.75],
    [0.67, 0.22, 0.5],
    [0.85, 0.33, 0.8],
    [0.77, 0.08, 0.4],
    [0.54, 0.37, 0.45],
    [0.42, 0.26, 0.6],
    [0.93, 0.15, 0.55],
    [0.60, 0.04, 0.35],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (final s in _stars) {
      paint.color = Colors.white.withValues(alpha: s[2]);
      canvas.drawCircle(
        Offset(s[0] * size.width, s[1] * size.height * 0.4 + 40),
        1.5,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Gently floats its child up and down, like the island in the preview.
/// Stays still when the system asks to reduce motion.
class FloatingArt extends StatefulWidget {
  const FloatingArt({super.key, required this.child, this.distance = 6});

  final Widget child;
  final double distance;

  @override
  State<FloatingArt> createState() => _FloatingArtState();
}

class _FloatingArtState extends State<FloatingArt>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_controller.value);
        return Transform.translate(
          offset: Offset(0, (t - 0.5) * 2 * widget.distance),
          child: child,
        );
      },
    );
  }
}

/// Section title used on the home sheet.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
              color: AppColors.ink,
            ),
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

/// Small pill marking new features.
class NewBadge extends StatelessWidget {
  const NewBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.secondary,
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Text(
        'BARU',
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
          color: Colors.white,
        ),
      ),
    );
  }
}
