import 'package:flutter/material.dart';

import 'package:muslimku/core/theme/app_colors.dart';
import 'package:muslimku/core/theme/app_text_styles.dart';
import 'package:muslimku/features/asmaul_husna/application/asmaul_husna_provider.dart';
import 'package:muslimku/shared/widgets/senja/senja.dart';

/// "Nama hari ini" (design a1): the feature card look of [SenjaFeatureCard]
/// with the Arabic name on the right. The text column keeps clear of the
/// Arabic, so long names (e.g. Dzul-Jalâli wal-Ikram) never run under it.
class HusnaTodayCard extends StatelessWidget {
  const HusnaTodayCard({
    super.key,
    required this.name,
    required this.total,
    required this.onDzikir,
    required this.onShare,
  });

  final HusnaName name;
  final int total;
  final VoidCallback onDzikir;
  final VoidCallback onShare;

  static const _radius = 24.0;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 142),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_radius),
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_radius),
        child: CustomPaint(
          painter: OctagramPatternPainter(
            color: Colors.white.withValues(alpha: 0.12),
          ),
          child: Padding(
            // The pills keep the mock's 32 px; [_TapArea] adds 4 px above and
            // below, so the bottom padding is 10 instead of 14.
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) => Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _texts()),
                      const SizedBox(width: 12),
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: constraints.maxWidth * 0.44,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: Text(
                              name.arabic,
                              textDirection: TextDirection.rtl,
                              style: const TextStyle(
                                fontFamily: AppTextStyles.arabicFontFamily,
                                fontSize: 44,
                                height: 1.4,
                                color: Colors.white,
                                shadows: [
                                  Shadow(
                                    color: Color(0x590F0846),
                                    offset: Offset(0, 6),
                                    blurRadius: 20,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    _TapArea(
                      onTap: onDzikir,
                      child: SenjaPill(
                        label: 'Dzikir 33×',
                        icon: Icons.blur_circular_rounded,
                        height: 32,
                        onTap: onDzikir,
                      ),
                    ),
                    _TapArea(
                      onTap: onShare,
                      child: SenjaPill(
                        label: 'Bagikan',
                        icon: Icons.ios_share_rounded,
                        lime: false,
                        height: 32,
                        onTap: onShare,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _texts() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: SenjaCaption('Nama hari ini · ${name.number} dari $total'),
        ),
        const SizedBox(height: 18),
        Text(
          name.latin,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 20,
            height: 1.25,
            letterSpacing: -0.3,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          name.meaning,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12.5,
            height: 1.35,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.82),
          ),
        ),
      ],
    );
  }
}

/// Grows the tap area of a 32 px pill to 40 px without changing its look.
class _TapArea extends StatelessWidget {
  const _TapArea({required this.onTap, required this.child});

  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: child,
      ),
    );
  }
}
