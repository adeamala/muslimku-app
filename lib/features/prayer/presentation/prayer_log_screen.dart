import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:muslimku/core/theme/app_colors.dart';
import 'package:muslimku/core/theme/app_text_styles.dart';
import 'package:muslimku/core/time/clock_provider.dart';
import 'package:muslimku/features/prayer/application/prayer_log_provider.dart';
import 'package:muslimku/features/prayer/domain/adzan_plan.dart'
    show AdzanPrayer, AdzanPrayerLabel;
import 'package:muslimku/features/prayer/domain/prayer_log.dart';
import 'package:muslimku/shared/widgets/senja/senja.dart';

/// "Catatan sholat": today's five, the streak, and the last 30 days. Any
/// past day can be corrected here; Beranda only marks today.
class PrayerLogScreen extends ConsumerWidget {
  const PrayerLogScreen({super.key});

  static const days = 30;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final log = ref.watch(prayerLogProvider);
    final notifier = ref.read(prayerLogProvider.notifier);
    final now = ref.watch(clockProvider).valueOrNull ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final top = MediaQuery.paddingOf(context).top;
    final bottom = MediaQuery.paddingOf(context).bottom;
    final streak = log.currentStreak(today);
    final longest = log.longestStreak(today);
    final history = log.lastDays(today, days).reversed.toList();
    final dayFormat = DateFormat('EEE, d MMM', 'id_ID');
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: AppColors.stageBackground,
        body: DefaultTextStyle(
          style: TextStyle(
            fontFamily: AppTextStyles.fontFamily,
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.ink,
          ),
          child: ListView(
            padding: EdgeInsets.fromLTRB(16, top + 4, 16, bottom + 28),
            children: [
              Row(
                children: [
                  SenjaIconButton(
                    icon: Icons.arrow_back_rounded,
                    tooltip: 'Kembali',
                    iconSize: 24,
                    onPressed: () => Navigator.maybePop(context),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 8, 6, 2),
                child: Semantics(
                  header: true,
                  child: Text(
                    'Catatan sholat',
                    style: TextStyle(
                      fontSize: 30,
                      height: 1.15,
                      letterSpacing: -0.6,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 4, 6, 16),
                child: Text(
                  'Hanya tersimpan di HP ini. Hari lengkap = lima waktu.',
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.3,
                    fontWeight: FontWeight.w600,
                    color: AppColors.inkMuted,
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: _Stat(
                      icon: Icons.local_fire_department_rounded,
                      value: streak > 0
                          ? '$streak hari berturut-turut'
                          : 'Belum ada rangkaian',
                      caption: 'Rangkaian saat ini',
                      lit: streak > 0,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _Stat(
                      icon: Icons.emoji_events_rounded,
                      value: longest > 0
                          ? 'Terpanjang $longest hari'
                          : 'Belum ada',
                      caption: 'Rekor',
                      lit: longest > 0,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              SenjaSectionTitle(
                'Hari ini ${log.countOn(today)} dari 5',
                trailing: dayFormat.format(today),
              ),
              const SizedBox(height: 10),
              SenjaCard(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    for (final p in AdzanPrayer.values)
                      SenjaToggleRow(
                        label: p.label,
                        value: log.isDone(today, p),
                        onChanged: (_) => notifier.toggle(today, p),
                        divider: p != AdzanPrayer.values.last,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              const SenjaSectionTitle('30 hari terakhir'),
              const SizedBox(height: 10),
              SenjaCard(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    for (final (day, count) in history)
                      _DayRow(
                        key: ValueKey('log-${PrayerLog.key(day)}'),
                        label: day == today
                            ? 'Hari ini'
                            : dayFormat.format(day),
                        done: log.doneOn(day),
                        count: count,
                        divider: day != history.last.$1,
                        onToggle: (p) => notifier.toggle(day, p),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.icon,
    required this.value,
    required this.caption,
    required this.lit,
  });

  final IconData icon;
  final String value;
  final String caption;
  final bool lit;

  @override
  Widget build(BuildContext context) {
    return SenjaCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 22,
            color: lit ? AppColors.gold : AppColors.inkMuted,
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              height: 1.25,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            caption,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: AppColors.inkMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _DayRow extends StatelessWidget {
  const _DayRow({
    super.key,
    required this.label,
    required this.done,
    required this.count,
    required this.divider,
    required this.onToggle,
  });

  final String label;
  final Set<AdzanPrayer> done;
  final int count;
  final bool divider;
  final ValueChanged<AdzanPrayer> onToggle;

  @override
  Widget build(BuildContext context) {
    final complete = count == AdzanPrayer.values.length;
    return Container(
      constraints: const BoxConstraints(minHeight: 52),
      decoration: BoxDecoration(
        border: divider
            ? Border(bottom: BorderSide(color: AppColors.lilacLine))
            : null,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: count == 0 ? AppColors.inkMuted : AppColors.ink,
              ),
            ),
          ),
          for (final p in AdzanPrayer.values)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Semantics(
                button: true,
                toggled: done.contains(p),
                label: '$label, ${p.label}',
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => onToggle(p),
                  child: SizedBox(
                    width: 30,
                    height: 40,
                    child: Center(
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: done.contains(p)
                              ? (complete
                                    ? AppColors.gold
                                    : AppColors.secondary)
                              : AppColors.lilac,
                        ),
                        child: ExcludeSemantics(
                          child: Center(
                            child: Text(
                              p.label.substring(0, 1),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: done.contains(p)
                                    ? Colors.white
                                    : AppColors.inkMuted,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
