import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:muslimku/core/theme/app_colors.dart';

/// Eight-pointed star (two overlapping squares) used for numbers and patterns.
Path octagramPath(Offset center, double radius) {
  final inner = radius * math.cos(math.pi / 4) / math.cos(math.pi / 8);
  final path = Path();
  for (var k = 0; k < 16; k++) {
    final angle = -math.pi / 2 + k * math.pi / 8;
    final r = k.isEven ? radius : inner;
    final p = center + Offset(r * math.cos(angle), r * math.sin(angle));
    k == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
  }
  return path..close();
}

class OctagramPainter extends CustomPainter {
  const OctagramPainter({
    required this.fill,
    required this.stroke,
    this.strokeWidth = 1.7,
  });

  final Color fill;
  final Color stroke;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final path = octagramPath(
      size.center(Offset.zero),
      size.shortestSide / 2 * 0.925,
    );
    canvas.drawPath(path, Paint()..color = fill);
    canvas.drawPath(
      path,
      Paint()
        ..color = stroke
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(OctagramPainter old) =>
      old.fill != fill ||
      old.stroke != stroke ||
      old.strokeWidth != strokeWidth;
}

/// A number inside an eight-pointed star (surah, ayah, hadits, Asmaul Husna).
class OctagramBadge extends StatelessWidget {
  const OctagramBadge(
    this.label, {
    super.key,
    this.size = 38,
    this.gold = false,
  });

  final String label;
  final double size;

  /// Gold outline on a dark page (Mihrab Emas night mode).
  final bool gold;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: OctagramPainter(
          fill: gold ? AppColors.gold.withValues(alpha: 0.1) : AppColors.lilac,
          stroke: gold ? AppColors.gold : AppColors.secondary,
          strokeWidth: size >= 32 ? 1.7 : 1.4,
        ),
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(size * 0.2),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                textScaler: TextScaler.noScaling,
                style: TextStyle(
                  fontSize: size >= 32 ? 12.5 : 11,
                  fontWeight: FontWeight.w800,
                  color: gold ? AppColors.nightCream : AppColors.ink,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Faint tiled stars for feature cards (white on purple, or purple on lilac).
class OctagramPatternPainter extends CustomPainter {
  const OctagramPatternPainter({
    required this.color,
    this.tile = 40,
    this.radius = 13,
  });

  final Color color;
  final double tile;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var y = 0.0; y < size.height + tile; y += tile) {
      for (var x = 0.0; x < size.width + tile; x += tile) {
        canvas.drawPath(
          octagramPath(Offset(x + tile / 2, y + tile / 2), radius),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(OctagramPatternPainter old) => old.color != color;
}
