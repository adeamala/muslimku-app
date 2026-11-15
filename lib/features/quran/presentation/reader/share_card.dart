import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:muslimku/core/theme/app_colors.dart';
import 'package:muslimku/core/theme/app_text_styles.dart';
import 'package:muslimku/shared/widgets/senja/senja.dart';

/// Looks of the "Bagikan ayat" image (design q6).
enum ShareTemplate { senja, malam, terang }

extension ShareTemplateLabel on ShareTemplate {
  String get label => switch (this) {
    ShareTemplate.senja => 'Senja',
    ShareTemplate.malam => 'Malam',
    ShareTemplate.terang => 'Terang',
  };
}

class _Look {
  const _Look({
    required this.gradient,
    required this.reference,
    required this.arabic,
    required this.text,
    required this.brand,
    required this.diamond,
  });

  final Gradient gradient;
  final Color reference;
  final Color arabic;
  final Color text;
  final Color brand;
  final Color diamond;
}

const _senjaLook = _Look(
  gradient: LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      AppColors.duskTop,
      AppColors.duskHigh,
      AppColors.duskMid,
      AppColors.duskLow,
      Color(0xFFC9A3FF),
    ],
    stops: [0, 0.34, 0.64, 0.86, 1],
  ),
  reference: AppColors.primary,
  arabic: Colors.white,
  text: Color(0xEBFFFFFF),
  brand: Colors.white,
  diamond: AppColors.primary,
);

const _malamLook = _Look(
  gradient: LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [AppColors.duskNight, AppColors.nightSurface, Color(0xFF241A7A)],
    stops: [0, 0.5, 1],
  ),
  reference: AppColors.gold,
  arabic: AppColors.gold,
  text: Color(0xE6F6EEDC),
  brand: AppColors.nightCream,
  diamond: AppColors.gold,
);

const _terangLook = _Look(
  gradient: LinearGradient(colors: [Colors.white, Colors.white]),
  reference: AppColors.secondary,
  arabic: Color(0xFF16123A),
  text: Color(0xFF2C2754),
  brand: Color(0xFF16123A),
  diamond: AppColors.secondary,
);

/// The 280×350 (4:5) ayah card that is shared as an image. Text sizes do not
/// follow the phone setting, so the picture looks the same for everyone.
/// Long ayat are scaled down to fit.
class AyahShareCard extends StatelessWidget {
  const AyahShareCard({
    super.key,
    required this.template,
    required this.arabic,
    required this.reference,
    this.translation,
  });

  static const size = Size(280, 350);

  final ShareTemplate template;
  final String arabic;

  /// "QS Asy-Syarh 94:5".
  final String reference;
  final String? translation;

  @override
  Widget build(BuildContext context) {
    final look = switch (template) {
      ShareTemplate.senja => _senjaLook,
      ShareTemplate.malam => _malamLook,
      ShareTemplate.terang => _terangLook,
    };
    final light = template == ShareTemplate.terang;
    return MediaQuery.withNoTextScaling(
      child: SizedBox.fromSize(
        size: size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: look.gradient,
            borderRadius: BorderRadius.circular(24),
            border: light
                ? Border.all(color: AppColors.lilacLine, width: 1.5)
                : null,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: light
                        ? OctagramPatternPainter(
                            color: AppColors.secondary.withValues(alpha: 0.06),
                          )
                        : const _StarsPainter(),
                  ),
                ),
                if (template == ShareTemplate.malam)
                  Positioned(
                    left: -40,
                    right: -40,
                    bottom: -150,
                    height: 300,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          colors: [
                            AppColors.gold.withValues(alpha: 0.22),
                            AppColors.gold.withValues(alpha: 0),
                          ],
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  right: 18,
                  top: 16,
                  child: Image.asset(
                    'images/3d/moon.webp',
                    width: 34,
                    excludeFromSemantics: true,
                  ),
                ),
                if (template == ShareTemplate.senja)
                  Positioned(
                    right: -16,
                    bottom: -30,
                    child: Opacity(
                      opacity: 0.95,
                      child: Image.asset(
                        'images/3d/diorama_senja.webp',
                        width: 150,
                        excludeFromSemantics: true,
                      ),
                    ),
                  ),
                Positioned(
                  left: 18,
                  right: 64,
                  top: 22,
                  child: Text(
                    reference.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 0.8,
                      fontWeight: FontWeight.w800,
                      color: look.reference,
                    ),
                  ),
                ),
                Positioned(
                  left: 14,
                  right: 14,
                  top: 60,
                  bottom: 52,
                  child: Align(
                    alignment: const Alignment(0, -0.35),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: SizedBox(
                        width: 252,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              arabic,
                              textAlign: TextAlign.center,
                              textDirection: TextDirection.rtl,
                              style: TextStyle(
                                fontFamily: AppTextStyles.arabicFontFamily,
                                fontSize: 27,
                                height: 1.75,
                                color: look.arabic,
                              ),
                            ),
                            if (translation != null &&
                                translation!.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                ),
                                child: Text(
                                  '“$translation”',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    height: 1.55,
                                    fontWeight: FontWeight.w600,
                                    color: look.text,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 18,
                  bottom: 18,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Transform.rotate(
                        angle: math.pi / 4,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: look.diamond,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                      const SizedBox(width: 7),
                      Text(
                        'Muslimku',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: look.brand,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Small template preview tile (design `.tpc`).
class ShareTemplateSwatch extends StatelessWidget {
  const ShareTemplateSwatch({
    super.key,
    required this.template,
    required this.selected,
    required this.onTap,
  });

  final ShareTemplate template;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (Gradient? gradient, Color text) = switch (template) {
      ShareTemplate.senja => (
        const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.duskHigh, AppColors.duskLow],
        ),
        Colors.white,
      ),
      ShareTemplate.malam => (
        const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.duskNight, Color(0xFF241A7A)],
        ),
        AppColors.gold,
      ),
      ShareTemplate.terang => (null, AppColors.ayahDeep),
    };
    return Semantics(
      button: true,
      selected: selected,
      label: 'Template ${template.label}',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(2.5),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(19),
                border: Border.all(
                  color: selected ? AppColors.secondary : Colors.transparent,
                  width: 2.5,
                ),
              ),
              child: Container(
                width: 58,
                height: 72,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: gradient == null ? Colors.white : null,
                  gradient: gradient,
                  borderRadius: BorderRadius.circular(14),
                  border: gradient == null
                      ? Border.all(color: AppColors.lilacLine, width: 1.5)
                      : null,
                ),
                child: Text(
                  'آية',
                  textDirection: TextDirection.rtl,
                  textScaler: TextScaler.noScaling,
                  style: TextStyle(
                    fontFamily: AppTextStyles.arabicFontFamily,
                    fontSize: 20,
                    height: 1.4,
                    color: text,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              template.label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: AppColors.inkMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fixed scattering of small stars in the upper part of the card.
class _StarsPainter extends CustomPainter {
  const _StarsPainter();

  static final List<(Offset, double, double)> _stars = () {
    final random = math.Random(11);
    return [
      for (var i = 0; i < 18; i++)
        (
          Offset(
            10 + random.nextDouble() * 260,
            10 + random.nextDouble() * 150,
          ),
          [1.2, 1.7, 2.2][random.nextInt(3)] / 2,
          [0.5, 0.7, 0.9][random.nextInt(3)],
        ),
    ];
  }();

  @override
  void paint(Canvas canvas, Size size) {
    for (final (center, radius, alpha) in _stars) {
      canvas.drawCircle(
        center,
        radius,
        Paint()..color = Colors.white.withValues(alpha: alpha),
      );
    }
  }

  @override
  bool shouldRepaint(_StarsPainter oldDelegate) => false;
}
