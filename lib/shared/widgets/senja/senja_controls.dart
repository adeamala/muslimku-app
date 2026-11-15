import 'package:flutter/material.dart';

import 'package:muslimku/core/theme/app_colors.dart';
import 'package:muslimku/shared/widgets/senja/senja_cards.dart';

/// One item of [SenjaSegmented].
class SenjaSegment {
  const SenjaSegment(this.label, {this.count});

  final String label;
  final int? count;
}

/// Pill tabs on lilac; the selected one is purple (design `.seg`).
class SenjaSegmented extends StatelessWidget {
  const SenjaSegmented({
    super.key,
    required this.items,
    required this.selected,
    required this.onChanged,
  });

  final List<SenjaSegment> items;
  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.lilac,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            Expanded(
              flex: items[i].label.length + (items[i].count == null ? 2 : 5),
              child: _SegmentButton(
                item: items[i],
                selected: i == selected,
                onTap: () => onChanged(i),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  const _SegmentButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final SenjaSegment item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? Colors.white : AppColors.inkMuted;
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: selected ? AppColors.secondary : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppColors.secondary.withValues(alpha: 0.28),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text.rich(
              TextSpan(
                text: item.label,
                children: [
                  if (item.count != null)
                    TextSpan(
                      text: ' ${item.count}',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: color.withValues(alpha: 0.7),
                      ),
                    ),
                ],
              ),
              maxLines: 1,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Lilac search box (design `.search`), with an optional trailing button.
class SenjaSearchField extends StatelessWidget {
  const SenjaSearchField({
    super.key,
    required this.hint,
    this.controller,
    this.onChanged,
    this.onSubmitted,
    this.trailing,
    this.keyboardType,
  });

  final String hint;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final Widget? trailing;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.only(left: 16, right: 7),
      decoration: BoxDecoration(
        color: AppColors.lilac,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Icons.search_rounded, size: 21, color: AppColors.inkMuted),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              onSubmitted: onSubmitted,
              keyboardType: keyboardType,
              textInputAction: TextInputAction.search,
              cursorColor: AppColors.secondary,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
              decoration: InputDecoration.collapsed(
                hintText: hint,
                hintStyle: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.inkMuted,
                ),
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// White square button inside the search box (e.g. the filter "tune" icon).
class SenjaSearchAction extends StatelessWidget {
  const SenjaSearchAction({
    super.key,
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.active = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? '',
      child: Material(
        color: active ? AppColors.secondary : AppColors.surface,
        borderRadius: BorderRadius.circular(11),
        child: InkWell(
          borderRadius: BorderRadius.circular(11),
          onTap: onTap,
          child: SizedBox.square(
            dimension: 34,
            child: Icon(
              icon,
              size: 19,
              color: active ? Colors.white : AppColors.secondary,
            ),
          ),
        ),
      ),
    );
  }
}

/// Rounded filter chip with an optional count (design `.chip`).
class SenjaChip extends StatelessWidget {
  const SenjaChip({
    super.key,
    required this.label,
    this.count,
    this.selected = false,
    this.onTap,
    this.icon,
  });

  final String label;
  final int? count;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final color = selected ? Colors.white : AppColors.inkMuted;
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: selected ? AppColors.secondary : AppColors.surface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? AppColors.secondary : AppColors.lilacLine,
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 16,
                  color: selected ? AppColors.primary : AppColors.secondary,
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              if (count != null) ...[
                const SizedBox(width: 5),
                Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: color.withValues(alpha: 0.65),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

enum SenjaIconStyle { plain, lilac, goldOutline, goldFilled, goldSoft }

/// 40 px icon button with radius 14 (design `.ibtn`).
class SenjaIconButton extends StatelessWidget {
  const SenjaIconButton({
    super.key,
    this.icon,
    this.child,
    required this.onPressed,
    required this.tooltip,
    this.style = SenjaIconStyle.plain,
    this.color,
    this.size = 40,
    this.iconSize = 22,
  }) : assert(icon != null || child != null);

  final IconData? icon;

  /// Used instead of [icon], e.g. the "Aa" label.
  final Widget? child;
  final VoidCallback? onPressed;
  final String tooltip;
  final SenjaIconStyle style;

  /// Icon colour for [SenjaIconStyle.plain]; defaults to the inherited colour.
  final Color? color;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg, BorderSide side) = switch (style) {
      SenjaIconStyle.plain => (
        Colors.transparent,
        color ?? IconTheme.of(context).color ?? AppColors.ink,
        BorderSide.none,
      ),
      SenjaIconStyle.lilac => (
        AppColors.lilac,
        AppColors.secondary,
        BorderSide.none,
      ),
      SenjaIconStyle.goldOutline => (
        Colors.transparent,
        AppColors.gold,
        BorderSide(color: AppColors.gold.withValues(alpha: 0.6), width: 1.5),
      ),
      SenjaIconStyle.goldFilled => (
        AppColors.gold,
        AppColors.duskNight,
        BorderSide.none,
      ),
      SenjaIconStyle.goldSoft => (
        AppColors.goldSoft,
        AppColors.gold,
        BorderSide.none,
      ),
    };
    return Tooltip(
      message: tooltip,
      child: Material(
        color: bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: side,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onPressed,
          child: SizedBox.square(
            dimension: size,
            child: Center(
              child: IconTheme.merge(
                data: IconThemeData(color: fg, size: iconSize),
                child: DefaultTextStyle.merge(
                  style: TextStyle(
                    color: fg,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                  child: child ?? Icon(icon),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Purple switch, 46×28 (design `.sw`).
class SenjaSwitch extends StatelessWidget {
  const SenjaSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.gold = false,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool gold;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 46,
      height: 28,
      child: FittedBox(
        child: Switch(
          value: value,
          onChanged: onChanged,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          activeColor: Colors.white,
          activeTrackColor: gold ? AppColors.gold : AppColors.secondary,
          inactiveThumbColor: Colors.white,
          inactiveTrackColor: AppColors.lilacLine,
          trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
          thumbIcon: const WidgetStatePropertyAll(Icon(null)),
        ),
      ),
    );
  }
}

/// Label + switch row, 50 px, with a hairline below (design `.tgl`).
class SenjaToggleRow extends StatelessWidget {
  const SenjaToggleRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.tag,
    this.icon,
    this.subtitle,
    this.divider = true,
  });

  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;

  /// Small lilac tag after the label, e.g. "segera".
  final String? tag;
  final IconData? icon;

  /// Muted line under the label.
  final String? subtitle;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Container(
        constraints: const BoxConstraints(minHeight: 50),
        decoration: BoxDecoration(
          border: divider
              ? Border(bottom: BorderSide(color: AppColors.lilacLine))
              : null,
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 19, color: AppColors.secondary),
              const SizedBox(width: 10),
            ],
            Flexible(
              // With a subtitle the text gets most of the row; the Spacer
              // after it only keeps a tag close to a short label.
              flex: subtitle == null ? 1 : 6,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  vertical: subtitle == null ? 0 : 8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontSize: 11.5,
                          height: 1.35,
                          fontWeight: FontWeight.w600,
                          color: AppColors.inkMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (tag != null) ...[const SizedBox(width: 8), SenjaTag(tag!)],
            const Spacer(),
            SenjaSwitch(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}

/// One option of a single-choice list in a sheet: lilac icon tile, title,
/// subtitle, optional [trailing] (e.g. a play button) and a check when
/// [selected]. 62 px rows like the settings screen.
class SenjaChoiceRow extends StatelessWidget {
  const SenjaChoiceRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    this.trailing,
    this.divider = true,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;
  final Widget? trailing;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 62),
          decoration: BoxDecoration(
            border: divider
                ? Border(bottom: BorderSide(color: AppColors.lilacLine))
                : null,
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: selected ? AppColors.secondary : AppColors.lilac,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 19,
                  color: selected ? Colors.white : AppColors.secondary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 11.5,
                          height: 1.35,
                          fontWeight: FontWeight.w600,
                          color: AppColors.inkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 6), trailing!],
              const SizedBox(width: 8),
              ExcludeSemantics(
                child: Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: 22,
                  color: selected ? AppColors.secondary : AppColors.lilacLine,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small lilac label, e.g. "segera" or "Harian".
class SenjaTag extends StatelessWidget {
  const SenjaTag(this.text, {super.key, this.dark = false});

  final String text;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: dark ? AppColors.ink : AppColors.lilac,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: dark ? AppColors.primary : AppColors.secondary,
        ),
      ),
    );
  }
}

/// Small lilac action in a settings row, e.g. "Simpan" (design `.sbtn`).
class SenjaSmallButton extends StatelessWidget {
  const SenjaSmallButton({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap == null ? 0.6 : 1,
      child: Material(
        color: AppColors.lilac,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 36, minWidth: 64),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.center,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: AppColors.secondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum SenjaButtonStyle { purple, lime, outline }

/// Full-width button, 54 px, radius 18 (design `.pbtn`, `.lbtn`, `.obtn`).
class SenjaButton extends StatelessWidget {
  const SenjaButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.style = SenjaButtonStyle.purple,
    this.height = 54,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final SenjaButtonStyle style;
  final double height;

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg) = switch (style) {
      SenjaButtonStyle.purple => (AppColors.secondary, Colors.white),
      SenjaButtonStyle.lime => (AppColors.primary, AppColors.ink),
      SenjaButtonStyle.outline => (AppColors.surface, AppColors.ink),
    };
    final disabled = onPressed == null;
    return Opacity(
      opacity: disabled ? 0.5 : 1,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: style == SenjaButtonStyle.outline
              ? Border.all(color: AppColors.lilacLine, width: 1.5)
              : null,
          boxShadow: style == SenjaButtonStyle.purple && !disabled
              ? [
                  BoxShadow(
                    color: AppColors.secondary.withValues(alpha: 0.3),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: bg,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onPressed,
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 19, color: fg),
                    const SizedBox(width: 8),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: fg,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Small rounded pill button on purple cards ("Putar murottal", "Dzikir 33×").
class SenjaPill extends StatelessWidget {
  const SenjaPill({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.lime = true,
    this.height = 36,
  });

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;

  /// Lime with dark text, or translucent white with white text.
  final bool lime;
  final double height;

  @override
  Widget build(BuildContext context) {
    final fg = lime ? AppColors.ink : Colors.white;
    return Material(
      color: lime ? AppColors.primary : Colors.white.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          height: height,
          padding: const EdgeInsets.only(left: 12, right: 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 17, color: fg),
                const SizedBox(width: 6),
              ],
              // Shrinks instead of overflowing at large text scales.
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: fg,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "‹  Oktober 2026  ›" bar above a month view.
class SenjaMonthBar extends StatelessWidget {
  const SenjaMonthBar({
    super.key,
    required this.label,
    required this.onPrevious,
    required this.onNext,
  });

  final String label;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return SenjaCard(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          SenjaIconButton(
            icon: Icons.chevron_left_rounded,
            tooltip: 'Bulan lalu',
            style: SenjaIconStyle.lilac,
            size: 36,
            iconSize: 22,
            onPressed: onPrevious,
          ),
          Expanded(
            child: Semantics(
              liveRegion: true,
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
            ),
          ),
          SenjaIconButton(
            icon: Icons.chevron_right_rounded,
            tooltip: 'Bulan depan',
            style: SenjaIconStyle.lilac,
            size: 36,
            iconSize: 22,
            onPressed: onNext,
          ),
        ],
      ),
    );
  }
}
