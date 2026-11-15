import 'package:flutter/material.dart';

import 'package:muslimku/core/theme/app_colors.dart';
import 'package:muslimku/shared/widgets/senja/octagram.dart';

/// Purple gradient card with faint stars (design `.feat`): "Lanjutkan membaca",
/// "Hadits hari ini", "Nama hari ini".
class SenjaFeatureCard extends StatelessWidget {
  const SenjaFeatureCard({
    super.key,
    required this.caption,
    required this.title,
    this.subtitle,
    this.child,
    this.trailing,
    this.watermark,
    this.onTap,
    this.height,
    this.padding = const EdgeInsets.fromLTRB(18, 16, 18, 16),
    this.titleSize = 21,
  });

  /// Lime uppercase line on top, e.g. "Lanjutkan membaca".
  final String caption;
  final String title;

  /// 21 px by default; "Hadits hari ini" uses 19 (design h1 `.hday .cn`).
  final double titleSize;
  final String? subtitle;

  /// Extra content under the subtitle (progress bar, buttons).
  final Widget? child;

  /// Usually a [SenjaGoButton], pinned to the bottom right.
  final Widget? trailing;

  /// Large faint decoration behind the text (e.g. the surah name in Arabic).
  final Widget? watermark;
  final VoidCallback? onTap;
  final double? height;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.featureTop,
            AppColors.secondary,
            AppColors.duskHigh,
          ],
          stops: [0, 0.42, 1],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.secondary.withValues(alpha: 0.26),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: OctagramPatternPainter(
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                  ),
                ),
                if (watermark != null) watermark!,
                Padding(
                  padding: padding,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SenjaCaption(caption),
                      const SizedBox(height: 5),
                      Padding(
                        padding: EdgeInsets.only(
                          right: trailing == null ? 0 : 56,
                        ),
                        child: Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: titleSize,
                            height: 1.25,
                            letterSpacing: -0.3,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Padding(
                          padding: EdgeInsets.only(
                            right: trailing == null ? 0 : 56,
                          ),
                          child: Text(
                            subtitle!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.5,
                              height: 1.4,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withValues(alpha: 0.82),
                            ),
                          ),
                        ),
                      ],
                      if (child != null) child!,
                    ],
                  ),
                ),
                if (trailing != null)
                  Positioned(right: 16, bottom: 16, child: trailing!),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Lime uppercase caption used on purple cards.
class SenjaCaption extends StatelessWidget {
  const SenjaCaption(this.text, {super.key, this.color = AppColors.primary});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 10.5,
        letterSpacing: 1.2,
        fontWeight: FontWeight.w800,
        color: color,
      ),
    );
  }
}

/// Round lime button (48 px) on feature cards.
class SenjaGoButton extends StatelessWidget {
  const SenjaGoButton({
    super.key,
    required this.icon,
    required this.tooltip,
    this.onPressed,
    this.size = 48,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: AppColors.primary,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox.square(
            dimension: size,
            child: Icon(icon, color: AppColors.ink, size: size * 0.46),
          ),
        ),
      ),
    );
  }
}

/// White card with a lilac outline and a 3 px lilac "lip" (design `.jc`, `.hc`, `.pt`).
class SenjaCard extends StatelessWidget {
  const SenjaCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(14),
    this.radius = 18,
    this.selected = false,
    this.color,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  final double radius;
  final bool selected;

  /// Defaults to the surface colour (white by day).
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final shape = BorderRadius.circular(radius);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: shape,
        boxShadow: [
          BoxShadow(color: AppColors.lilac, offset: const Offset(0, 3)),
        ],
      ),
      child: Material(
        color: selected
            ? AppColors.stageBackground
            : color ?? AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: shape,
          side: BorderSide(
            color: selected ? AppColors.secondary : AppColors.lilacLine,
            width: 1.5,
          ),
        ),
        child: InkWell(
          borderRadius: shape,
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// "Favorit                      Lihat semua" (design `.shead`).
class SenjaSectionTitle extends StatelessWidget {
  const SenjaSectionTitle(
    this.title, {
    super.key,
    this.trailing,
    this.onTrailing,
  });

  final String title;
  final String? trailing;
  final VoidCallback? onTrailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
        ),
        if (trailing != null)
          GestureDetector(
            onTap: onTrailing,
            child: Text(
              trailing!,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: onTrailing == null
                    ? FontWeight.w700
                    : FontWeight.w800,
                color: onTrailing == null
                    ? AppColors.inkMuted
                    : AppColors.secondary,
              ),
            ),
          ),
      ],
    );
  }
}

/// List row: star badge, two lines of text, trailing widget, hairline below
/// (design `.row`).
class SenjaListRow extends StatelessWidget {
  const SenjaListRow({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.titleMaxLines = 1,
    this.dimmed = false,
    this.padding = const EdgeInsets.symmetric(vertical: 12),
    this.below,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final int titleMaxLines;

  /// Extra content under the subtitle, e.g. a highlighted excerpt.
  final Widget? below;

  /// Not available right now (e.g. a surah that is not saved while offline).
  final bool dimmed;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: dimmed ? 0.45 : 1,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.lilacLine)),
          ),
          child: Row(
            crossAxisAlignment: titleMaxLines > 1 || below != null
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.center,
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: 14)],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: titleMaxLines,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15.5,
                        height: 1.3,
                        letterSpacing: -0.1,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.inkMuted,
                        ),
                      ),
                    ],
                    if (below != null) below!,
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 10), trailing!],
            ],
          ),
        ),
      ),
    );
  }
}

/// Thin progress bar (lime on translucent white, or purple on lilac).
class SenjaProgressBar extends StatelessWidget {
  const SenjaProgressBar({
    super.key,
    required this.value,
    this.onPurple = false,
    this.height = 6,
  });

  final double value;
  final bool onPurple;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: LinearProgressIndicator(
        value: value.clamp(0, 1),
        minHeight: height,
        backgroundColor: onPurple
            ? Colors.white.withValues(alpha: 0.22)
            : AppColors.lilac,
        valueColor: AlwaysStoppedAnimation(
          onPurple ? AppColors.primary : AppColors.secondary,
        ),
      ),
    );
  }
}
