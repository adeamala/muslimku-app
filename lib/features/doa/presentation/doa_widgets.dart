import 'package:flutter/material.dart';
import 'package:muslimku/core/theme/app_colors.dart';
import 'package:muslimku/features/doa/application/doa_provider.dart';
import 'package:muslimku/shared/widgets/senja/senja.dart';
import 'package:share_plus/share_plus.dart';

/// Star of the design (`ic('star')` / `ic('starf')`): an outline in muted ink,
/// or ink filled with a gold edge for favourites.
class DoaStar extends StatelessWidget {
  const DoaStar({super.key, required this.filled, this.size = 20});

  final bool filled;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _StarPainter(filled)),
    );
  }
}

class _StarPainter extends CustomPainter {
  const _StarPainter(this.filled);

  final bool filled;

  /// Points of the 24×24 icon path.
  static const _points = [
    Offset(12, 2.8),
    Offset(14.8, 8.6),
    Offset(21.2, 9.5),
    Offset(16.6, 14),
    Offset(17.7, 20.3),
    Offset(12, 17.3),
    Offset(6.3, 20.3),
    Offset(7.4, 14),
    Offset(2.8, 9.5),
    Offset(9.2, 8.6),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / 24;
    final path = Path()..addPolygon([for (final p in _points) p * scale], true);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = (filled ? 1.5 : 2) * scale
      ..color = filled ? AppColors.gold : AppColors.inkMuted;
    if (filled) canvas.drawPath(path, Paint()..color = AppColors.ink);
    canvas.drawPath(path, stroke);
  }

  @override
  bool shouldRepaint(_StarPainter old) => old.filled != filled;
}

/// 40 px star toggle for list rows and the doa page.
class DoaStarButton extends StatelessWidget {
  const DoaStarButton({
    super.key,
    required this.favourite,
    required this.onPressed,
    this.soft = false,
  });

  final bool favourite;
  final VoidCallback onPressed;

  /// Cream square behind a favourite (doa page app bar).
  final bool soft;

  @override
  Widget build(BuildContext context) {
    return SenjaIconButton(
      tooltip: favourite ? 'Hapus dari favorit' : 'Simpan ke favorit',
      style: soft && favourite ? SenjaIconStyle.goldSoft : SenjaIconStyle.plain,
      onPressed: onPressed,
      child: DoaStar(filled: favourite, size: soft ? 22 : 21),
    );
  }
}

/// Card in the "Favorit" strip (design `.fav`, 146×92).
class DoaFavouriteCard extends StatelessWidget {
  const DoaFavouriteCard({super.key, required this.doa, required this.onTap});

  final Doa doa;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(18);
    return Material(
      color: AppColors.stageBackground,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: AppColors.lilacLine, width: 1.5),
      ),
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Container(
          width: 146,
          padding: const EdgeInsets.fromLTRB(13, 12, 13, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const DoaStar(filled: true, size: 18),
              const Spacer(),
              Text(
                doa.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.26,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                doa.categoryLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  height: 1.2,
                  fontWeight: FontWeight.w600,
                  color: AppColors.inkMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Half of the bottom bar on the doa page (design `.nb2`): a caption and the
/// neighbouring doa title; [next] is purple and aligned to the right.
class DoaStepButton extends StatelessWidget {
  const DoaStepButton({
    super.key,
    required this.caption,
    required this.label,
    required this.onPressed,
    this.next = false,
  });

  final String caption;
  final String label;
  final VoidCallback onPressed;
  final bool next;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(16);
    return Semantics(
      button: true,
      label: '$caption: $label',
      excludeSemantics: true,
      child: Material(
        color: next ? AppColors.secondary : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(
            color: next ? AppColors.secondary : AppColors.lilacLine,
            width: 1.5,
          ),
        ),
        child: InkWell(
          borderRadius: radius,
          onTap: onPressed,
          child: Container(
            constraints: const BoxConstraints(minHeight: 50),
            // 12 rather than the mock's 14: the bar's border takes 2 px, and
            // "Doa Ketika Bercermin" should still fit.
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: next
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                Text(
                  caption,
                  maxLines: 1,
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
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: next ? Colors.white : AppColors.ink,
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

Future<void> shareDoa(Doa doa) async {
  try {
    await SharePlus.instance.share(ShareParams(text: doa.shareText));
  } catch (_) {
    // No share sheet on this platform; nothing to do.
  }
}
