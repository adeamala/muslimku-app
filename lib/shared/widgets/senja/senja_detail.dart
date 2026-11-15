import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:muslimku/core/theme/app_colors.dart';
import 'package:muslimku/shared/widgets/senja/senja_controls.dart';

/// Top bar of detail pages: back, centred title + subtitle, actions
/// (design `.abar`). Put it at the top of a page body; it adds the status bar
/// inset itself.
class SenjaDetailAppBar extends StatelessWidget {
  const SenjaDetailAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
    this.leadingIcon = Icons.arrow_back_rounded,
    this.leadingTooltip = 'Kembali',
    this.onLeading,
    this.foreground,
    this.subtitleColor,
    this.background,
    this.dark = false,
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final IconData leadingIcon;
  final String leadingTooltip;

  /// Defaults to `Navigator.maybePop`.
  final VoidCallback? onLeading;

  /// Defaults: ink, inkMuted and the surface colour.
  final Color? foreground;
  final Color? subtitleColor;
  final Color? background;

  /// Light status bar icons (for dark pages).
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final foreground = this.foreground ?? AppColors.ink;
    final subtitleColor = this.subtitleColor ?? AppColors.inkMuted;
    final background = this.background ?? AppColors.surface;
    final top = MediaQuery.paddingOf(context).top;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: (dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
          .copyWith(statusBarColor: Colors.transparent),
      child: Container(
        color: background,
        padding: EdgeInsets.fromLTRB(12, top, 12, 0),
        height: top + 56,
        child: IconTheme.merge(
          data: IconThemeData(color: foreground),
          child: Row(
            children: [
              SenjaIconButton(
                icon: leadingIcon,
                tooltip: leadingTooltip,
                iconSize: 24,
                color: foreground,
                onPressed: onLeading ?? () => Navigator.maybePop(context),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                        color: foreground,
                      ),
                    ),
                    if (subtitle != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 1),
                        child: Text(
                          subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: subtitleColor,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              if (actions.isEmpty) const SizedBox(width: 40),
              for (var i = 0; i < actions.length; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                actions[i],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// White floating bar at the bottom of detail pages (design `.dbar`).
class SenjaFloatingBar extends StatelessWidget {
  const SenjaFloatingBar({super.key, required this.child, this.height = 70});

  final Widget child;
  final double height;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(12, 0, 12, 14 + bottom),
      child: Container(
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.lilacLine),
          boxShadow: [
            BoxShadow(
              color: AppColors.ink.withValues(alpha: 0.14),
              blurRadius: 28,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}

/// "‹ No. 15" / "No. 17 ›" buttons in [SenjaFloatingBar].
class SenjaStepButton extends StatelessWidget {
  const SenjaStepButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.next = false,
    this.caption,
  });

  final String label;
  final VoidCallback? onPressed;

  /// Purple, arrow on the right.
  final bool next;

  /// Small line above the label ("Sebelumnya").
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final fg = next ? Colors.white : AppColors.ink;
    final text = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: next
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        if (caption != null)
          Text(
            caption!,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: next
                  ? Colors.white.withValues(alpha: 0.72)
                  : AppColors.inkMuted,
            ),
          ),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w800,
            color: fg,
          ),
        ),
      ],
    );
    return Opacity(
      opacity: onPressed == null ? 0.4 : 1,
      child: Material(
        color: next ? AppColors.secondary : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
          side: BorderSide(
            color: next ? AppColors.secondary : AppColors.lilacLine,
            width: 1.5,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap: onPressed,
          child: Container(
            height: caption == null ? 46 : 50,
            padding: EdgeInsets.only(left: next ? 14 : 8, right: next ? 8 : 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!next)
                  Icon(Icons.chevron_left_rounded, size: 22, color: fg),
                Flexible(child: text),
                if (next)
                  Icon(Icons.chevron_right_rounded, size: 22, color: fg),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Rounded bottom sheet with a handle and a title row (design `.bsheet`).
Future<T?> showSenjaSheet<T>(
  BuildContext context, {
  required String title,
  required WidgetBuilder builder,
  Widget? titleAction,
  bool scrollable = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.surface,
    barrierColor: AppColors.duskNight.withValues(alpha: 0.52),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (context) {
      final body = Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          10,
          20,
          20 +
              MediaQuery.viewInsetsOf(context).bottom +
              MediaQuery.paddingOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.lilacLine,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 40,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 19,
                        letterSpacing: -0.2,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                  if (titleAction != null) titleAction,
                ],
              ),
            ),
            Builder(builder: builder),
          ],
        ),
      );
      return scrollable ? SingleChildScrollView(child: body) : body;
    },
  );
}
