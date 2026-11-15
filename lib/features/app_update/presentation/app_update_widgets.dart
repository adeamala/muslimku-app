import 'package:flutter/material.dart';
import 'package:muslimku/core/theme/app_colors.dart';
import 'package:muslimku/features/app_update/application/app_update_provider.dart';
import 'package:muslimku/features/app_update/data/app_update_gateway.dart';
import 'package:muslimku/shared/widgets/senja/senja.dart';

enum UpdateChoice { update, later }

/// Offers [update] in the app's dusk style. Closing the sheet counts as
/// "Nanti saja".
Future<UpdateChoice> showAppUpdateSheet(
  BuildContext context,
  AvailableUpdate update,
) async {
  final choice = await showModalBottomSheet<UpdateChoice>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.surface,
    barrierColor: AppColors.duskNight.withValues(alpha: 0.52),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => AppUpdateSheet(update: update),
  );
  return choice ?? UpdateChoice.later;
}

class AppUpdateSheet extends StatelessWidget {
  const AppUpdateSheet({super.key, required this.update});

  final AvailableUpdate update;

  @override
  Widget build(BuildContext context) {
    final background = update.flexibleAllowed;
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          10,
          16,
          12 + MediaQuery.paddingOf(context).bottom,
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
            const SizedBox(height: 14),
            _UpdateHero(important: update.important),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    update.important
                        ? 'Pembaruan penting tersedia'
                        : 'Pembaruan tersedia',
                    style: TextStyle(
                      fontSize: 21,
                      letterSpacing: -0.3,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Versi terbaru Muslimku sudah ada di Google Play, '
                    'dengan perbaikan dan penyempurnaan terbaru.',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.45,
                      fontWeight: FontWeight.w500,
                      color: AppColors.inkMuted,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _UpdatePoint(
                    icon: background
                        ? Icons.download_for_offline_rounded
                        : Icons.shop_rounded,
                    title: background
                        ? 'Diunduh di latar belakang'
                        : 'Dipasang lewat Google Play',
                    subtitle: background
                        ? 'Aplikasi tetap bisa dipakai selama mengunduh'
                        : 'Prosesnya hanya sebentar',
                  ),
                  const SizedBox(height: 10),
                  const _UpdatePoint(
                    icon: Icons.verified_user_rounded,
                    title: 'Datamu tetap aman',
                    subtitle: 'Kota, bookmark, dan catatan tidak hilang',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            SenjaButton(
              label: 'Perbarui sekarang',
              icon: Icons.system_update_alt_rounded,
              onPressed: () => Navigator.of(context).pop(UpdateChoice.update),
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: 48,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(UpdateChoice.later),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.inkMuted,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: const Text(
                  'Nanti saja',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dusk card with the floating mosque, like the top of Beranda.
class _UpdateHero extends StatelessWidget {
  const _UpdateHero({required this.important});

  final bool important;

  static const _stars = [
    (0.08, 0.16, 2.5),
    (0.30, 0.10, 2.0),
    (0.46, 0.30, 1.6),
    (0.58, 0.08, 2.2),
    (0.22, 0.86, 1.8),
    (0.50, 0.62, 1.4),
  ];

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: SizedBox(
        height: 172,
        child: Stack(
          children: [
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.duskTop,
                      AppColors.duskHigh,
                      AppColors.duskMid,
                      AppColors.duskLow,
                    ],
                    stops: [0, 0.35, 0.75, 1],
                  ),
                ),
              ),
            ),
            LayoutBuilder(
              builder: (context, box) => Stack(
                children: [
                  for (final (x, y, r) in _stars)
                    Positioned(
                      left: box.maxWidth * x,
                      top: box.maxHeight * y,
                      child: Container(
                        width: r * 2,
                        height: r * 2,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.7),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Positioned(
              right: -22,
              bottom: -34,
              child: Image.asset(
                'images/3d/diorama_senja.webp',
                width: 196,
                excludeFromSemantics: true,
              ),
            ),
            Positioned(
              left: 18,
              top: 20,
              right: 150,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      important ? 'PENTING' : 'VERSI BARU',
                      style: const TextStyle(
                        fontSize: 11,
                        letterSpacing: 0.6,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF16123A),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Muslimku\nmakin nyaman',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 24,
                      height: 1.12,
                      letterSpacing: -0.4,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UpdatePoint extends StatelessWidget {
  const _UpdatePoint({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: AppColors.lilac,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, size: 22, color: AppColors.secondary),
        ),
        const SizedBox(width: 12),
        Expanded(
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
                  fontSize: 12.5,
                  height: 1.3,
                  fontWeight: FontWeight.w500,
                  color: AppColors.inkMuted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Floating card above the tab bar while the update downloads, then with
/// "Pasang" once it is ready.
class AppUpdateBanner extends StatelessWidget {
  const AppUpdateBanner({
    super.key,
    required this.phase,
    required this.onInstall,
    required this.onClose,
  });

  final UpdatePhase phase;
  final VoidCallback onInstall;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final ready = phase == UpdatePhase.ready;
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12),
        padding: const EdgeInsets.fromLTRB(12, 12, 6, 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [AppColors.duskTop, AppColors.duskHigh, AppColors.duskMid],
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.duskNight.withValues(alpha: 0.35),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: ready
                    ? AppColors.primary
                    : Colors.white.withValues(alpha: 0.14),
              ),
              alignment: Alignment.center,
              child: ready
                  ? const Icon(
                      Icons.check_rounded,
                      size: 22,
                      color: Color(0xFF16123A),
                    )
                  : SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.6,
                        color: AppColors.primary,
                        backgroundColor: Colors.white.withValues(alpha: 0.18),
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ready ? 'Pembaruan siap' : 'Mengunduh pembaruan…',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    ready
                        ? 'Pasang sekarang, cuma sebentar'
                        : 'Aplikasi tetap bisa dipakai',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.75),
                    ),
                  ),
                ],
              ),
            ),
            if (ready) ...[
              const SizedBox(width: 8),
              // Fixed dark label: AppColors.ink turns light in dark mode.
              Material(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(999),
                child: InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: onInstall,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    child: Text(
                      'Pasang',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF16123A),
                      ),
                    ),
                  ),
                ),
              ),
            ],
            IconButton(
              onPressed: onClose,
              tooltip: 'Tutup',
              visualDensity: VisualDensity.compact,
              icon: Icon(
                Icons.close_rounded,
                size: 20,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
