import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:muslimku/core/theme/app_colors.dart';
import 'package:muslimku/shared/widgets/senja/senja_controls.dart';
import 'package:shimmer/shimmer.dart';

/// Peach banner shown while saved data is used without internet (design `o1`).
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({
    super.key,
    this.title = 'Sedang offline',
    required this.message,
    this.savedAt,
    this.onRetry,
  });

  final String title;
  final String message;

  /// Adds "Data tersimpan 25 Okt" to the message.
  final DateTime? savedAt;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final saved = savedAt == null
        ? ''
        : ' Data tersimpan ${DateFormat('d MMM', 'id_ID').format(savedAt!)}.';
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        decoration: BoxDecoration(
          color: AppColors.offlineSurface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.offlineLine, width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.offlineIconBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.wifi_off_rounded,
                size: 19,
                color: AppColors.offlineAccent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    '$message$saved',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                      color: AppColors.inkMuted,
                    ),
                  ),
                ],
              ),
            ),
            if (onRetry != null)
              SenjaIconButton(
                icon: Icons.refresh_rounded,
                tooltip: 'Coba lagi',
                onPressed: onRetry,
                color: AppColors.offlineAccent,
              ),
          ],
        ),
      ),
    );
  }
}

/// Friendly empty / error page with a 3D illustration (design `o2`).
class SenjaEmptyState extends StatelessWidget {
  const SenjaEmptyState({
    super.key,
    required this.image,
    required this.title,
    required this.message,
    this.badgeIcon,
    this.primaryLabel,
    this.primaryIcon = Icons.refresh_rounded,
    this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
    this.tip,
    this.dark = false,
  });

  /// Asset path, e.g. `images/3d/icon_quran.webp`.
  final String image;
  final String title;
  final String message;

  /// Small round badge on the illustration, e.g. [Icons.wifi_off_rounded].
  final IconData? badgeIcon;
  final String? primaryLabel;
  final IconData primaryIcon;
  final VoidCallback? onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  /// Small hint at the bottom.
  final String? tip;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final titleColor = dark ? AppColors.nightCream : AppColors.ink;
    final textColor = dark ? AppColors.nightMuted : AppColors.inkMuted;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
      child: Column(
        children: [
          SizedBox(
            width: 220,
            height: 200,
            child: Stack(
              children: [
                Positioned(
                  left: 20,
                  top: 10,
                  child: Container(
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          dark ? AppColors.nightSurface : AppColors.lilac,
                          (dark ? AppColors.nightSurface : AppColors.lilac)
                              .withValues(alpha: 0),
                        ],
                        stops: const [0.82, 1],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 20,
                  right: 20,
                  top: 46,
                  child: Image.asset(
                    image,
                    height: 128,
                    excludeFromSemantics: true,
                  ),
                ),
                if (badgeIcon != null)
                  Positioned(
                    right: 26,
                    top: 26,
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: AppColors.offlineAccent,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: dark ? AppColors.duskNight : Colors.white,
                          width: 5,
                        ),
                      ),
                      child: Icon(badgeIcon, size: 19, color: Colors.white),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 21,
              letterSpacing: -0.3,
              fontWeight: FontWeight.w800,
              color: titleColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              height: 1.6,
              fontWeight: FontWeight.w500,
              color: textColor,
            ),
          ),
          if (primaryLabel != null) ...[
            const SizedBox(height: 24),
            SenjaButton(
              label: primaryLabel!,
              icon: primaryIcon,
              onPressed: onPrimary,
            ),
          ],
          if (secondaryLabel != null) ...[
            const SizedBox(height: 10),
            SenjaButton(
              label: secondaryLabel!,
              style: SenjaButtonStyle.outline,
              height: 52,
              onPressed: onSecondary,
            ),
          ],
          if (tip != null) ...[
            const SizedBox(height: 22),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.download_rounded, size: 16, color: textColor),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    tip!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Shimmering placeholder rows while a list loads. The shapes stand still when
/// the phone asks for less motion (`MediaQuery.disableAnimations`).
class SenjaSkeletonList extends StatelessWidget {
  const SenjaSkeletonList({
    super.key,
    this.rows = 6,
    this.padding = EdgeInsets.zero,
  });

  final int rows;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    // Lilac, so the shapes also show without the shimmer (which repaints
    // them with its own gradient).
    Widget bar(double width, double height) => Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.lilac,
        borderRadius: BorderRadius.circular(6),
      ),
    );
    final body = Padding(
      padding: padding,
      child: Column(
        children: [
          for (var i = 0; i < rows; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.lilac,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        bar(140, 14),
                        const SizedBox(height: 8),
                        bar(200, 10),
                      ],
                    ),
                  ),
                  bar(48, 18),
                ],
              ),
            ),
        ],
      ),
    );
    return Semantics(
      label: 'Memuat',
      child: MediaQuery.disableAnimationsOf(context)
          ? body
          : Shimmer.fromColors(
              baseColor: AppColors.lilac,
              highlightColor: const Color(0xFFF8F7FF),
              child: body,
            ),
    );
  }
}
