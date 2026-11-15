import 'package:flutter/material.dart';

import 'package:muslimku/core/theme/app_colors.dart';
import 'package:muslimku/core/theme/app_text_styles.dart';
import 'package:muslimku/shared/widgets/senja/octagram.dart';

/// Arabic text in Amiri, right to left. Quranic text should already be passed
/// through `normalizeQuranText` (the Quran models do this).
class ArabicText extends StatelessWidget {
  const ArabicText(
    this.text, {
    super.key,
    this.size = 28,
    this.color,
    this.align = TextAlign.right,
    this.height = 1.9,
    this.maxLines,
  });

  final String text;
  final double size;

  /// Defaults to `AppColors.ink`.
  final Color? color;
  final TextAlign align;

  /// Line height; Amiri's stacked marks need about 1.9.
  final double height;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textDirection: TextDirection.rtl,
      textAlign: align,
      maxLines: maxLines,
      overflow: maxLines == null ? null : TextOverflow.ellipsis,
      style: TextStyle(
        fontFamily: AppTextStyles.arabicFontFamily,
        fontSize: size,
        height: height,
        color: color ?? AppColors.ink,
      ),
    );
  }
}

/// Arabic on a soft lilac card with faint stars (design `.arcard`), used on
/// hadits and doa pages.
class ArabicCard extends StatelessWidget {
  const ArabicCard({
    super.key,
    required this.text,
    this.size = 24,
    this.align = TextAlign.right,
  });

  final String text;
  final double size;
  final TextAlign align;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.stageBackground,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.lilacLine, width: 1.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(21),
        child: CustomPaint(
          painter: OctagramPatternPainter(
            color: AppColors.secondary.withValues(alpha: 0.07),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
            child: ArabicText(text, size: size, align: align, height: 2.05),
          ),
        ),
      ),
    );
  }
}
