import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muslimku/core/theme/app_colors.dart';
import 'package:muslimku/features/prayer/application/prayer_log_provider.dart';
import 'package:muslimku/features/prayer/domain/adzan_plan.dart'
    show AdzanPrayer, AdzanPrayerLabel;
import 'package:muslimku/features/prayer/domain/prayer_schedule.dart'
    show timeOnDay;
import 'package:muslimku/features/prayer/domain/prayer_time_model.dart';
import 'package:muslimku/features/prayer/presentation/prayer_log_screen.dart';
import 'package:muslimku/shared/widgets/senja/senja.dart';

/// "Sudah sholat" card on Beranda: five chips for today, the streak line,
/// and a link to the log. A prayer can be marked once its time has come.
class PrayerLogStrip extends ConsumerWidget {
  const PrayerLogStrip({super.key, required this.today, required this.now});

  final PrayerSchedule? today;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final log = ref.watch(prayerLogProvider);
    final notifier = ref.read(prayerLogProvider.notifier);
    final done = log.countOn(now);
    final streak = log.currentStreak(now);
    return SenjaCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: true,
            label: 'Sudah sholat, $done dari 5, buka catatan sholat',
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const PrayerLogScreen(),
                ),
              ),
              child: ExcludeSemantics(
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Sudah sholat',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                    Text(
                      '$done dari 5',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.secondary,
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: AppColors.secondary,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (final p in AdzanPrayer.values) ...[
                if (p != AdzanPrayer.values.first) const SizedBox(width: 6),
                Expanded(
                  child: _Chip(
                    prayer: p,
                    done: log.isDone(now, p),
                    open: _hasCome(p),
                    onTap: () => notifier.toggle(now, p),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                Icons.local_fire_department_rounded,
                size: 16,
                color: streak > 0 ? AppColors.gold : AppColors.inkMuted,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  streak > 0
                      ? '$streak hari berturut-turut lengkap'
                      : 'Belum ada rangkaian',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.inkMuted,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  bool _hasCome(AdzanPrayer p) {
    final day = today;
    if (day == null) return true;
    final at = timeOnDay(now, p.timeIn(day));
    return at == null || !now.isBefore(at);
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.prayer,
    required this.done,
    required this.open,
    required this.onTap,
  });

  final AdzanPrayer prayer;
  final bool done;
  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = prayer.label;
    final tooltip = done
        ? 'Batalkan $label'
        : open
        ? 'Tandai $label sudah'
        : '$label belum masuk waktu';
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        enabled: open,
        toggled: done,
        label: tooltip,
        child: Material(
          color: done
              ? AppColors.secondary
              : open
              ? AppColors.lilac
              : AppColors.lilac.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: open ? onTap : null,
            child: SizedBox(
              height: 44,
              child: ExcludeSemantics(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      done ? Icons.check_rounded : Icons.circle_outlined,
                      size: 16,
                      color: done
                          ? Colors.white
                          : open
                          ? AppColors.secondary
                          : AppColors.inkMuted,
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        label,
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: done
                              ? Colors.white
                              : open
                              ? AppColors.ink
                              : AppColors.inkMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
