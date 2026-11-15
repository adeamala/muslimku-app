import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:muslimku/core/theme/app_colors.dart';
import 'package:muslimku/core/theme/app_text_styles.dart';
import 'package:muslimku/core/time/clock_provider.dart';
import 'package:muslimku/features/calendar/application/hijri_provider.dart';
import 'package:muslimku/features/calendar/domain/hijri.dart';
import 'package:muslimku/shared/widgets/senja/senja.dart';

/// Hijri month grid with the Gregorian day in each cell, the important days
/// of the year, and the ±1 day correction. Everything is computed offline.
class HijriCalendarScreen extends ConsumerStatefulWidget {
  const HijriCalendarScreen({super.key});

  @override
  ConsumerState<HijriCalendarScreen> createState() =>
      _HijriCalendarScreenState();
}

class _HijriCalendarScreenState extends ConsumerState<HijriCalendarScreen> {
  /// Months flipped away from the current one.
  int _offset = 0;

  @override
  Widget build(BuildContext context) {
    final adjust = ref.watch(hijriAdjustProvider);
    final now = ref.watch(clockProvider).valueOrNull ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todayHijri = HijriDate.fromDate(today, adjust: adjust);
    final month = todayHijri.firstOfMonth.addMonths(_offset);
    final upcoming = upcomingEvents(today, adjust: adjust);
    final top = MediaQuery.paddingOf(context).top;
    final bottom = MediaQuery.paddingOf(context).bottom;
    final first = month.toDate(adjust: adjust);
    final last = HijriDate(
      month.year,
      month.month,
      month.daysInMonth,
    ).toDate(adjust: adjust);
    final range =
        '${DateFormat('d MMM', 'id_ID').format(first)} – '
        '${DateFormat('d MMM yyyy', 'id_ID').format(last)}';
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
                  const Spacer(),
                  if (_offset != 0)
                    SenjaSmallButton(
                      label: 'Hari ini',
                      onTap: () => setState(() => _offset = 0),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 8, 6, 2),
                child: Semantics(
                  header: true,
                  child: Text(
                    'Kalender Hijriah',
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
                  'Hari ini ${todayHijri.label}',
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.3,
                    fontWeight: FontWeight.w600,
                    color: AppColors.inkMuted,
                  ),
                ),
              ),
              SenjaMonthBar(
                label: month.monthLabel,
                onPrevious: () => setState(() => _offset--),
                onNext: () => setState(() => _offset++),
              ),
              const SizedBox(height: 12),
              _MonthGrid(
                month: month,
                adjust: adjust,
                today: todayHijri,
                range: range,
              ),
              const SizedBox(height: 22),
              const SenjaSectionTitle('Hari besar berikutnya'),
              const SizedBox(height: 10),
              SenjaCard(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    for (final u in upcoming)
                      _EventRow(event: u, divider: u != upcoming.last),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              const SenjaSectionTitle('Koreksi tanggal'),
              const SizedBox(height: 10),
              SenjaCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Kalender ini dihitung (hisab). Bila pengumuman '
                      'pemerintah selisih sehari, geser di sini. Berlaku '
                      'di Beranda dan pengingat.',
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.45,
                        fontWeight: FontWeight.w600,
                        color: AppColors.inkMuted,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final (days, label) in const [
                          (-1, '−1 hari'),
                          (0, 'Sesuai'),
                          (1, '+1 hari'),
                        ])
                          SenjaChip(
                            label: label,
                            selected: adjust == days,
                            onTap: () => ref
                                .read(hijriAdjustProvider.notifier)
                                .set(days),
                          ),
                      ],
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

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.adjust,
    required this.today,
    required this.range,
  });

  final HijriDate month;
  final int adjust;
  final HijriDate today;
  final String range;

  static const _weekdays = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];

  @override
  Widget build(BuildContext context) {
    final first = month.toDate(adjust: adjust);
    final lead = first.weekday - 1; // Monday first
    final days = month.daysInMonth;
    final cells = <Widget>[
      for (var i = 0; i < lead; i++) const SizedBox.shrink(),
      for (var d = 1; d <= days; d++)
        _DayCell(
          key: ValueKey('hijri-day-$d'),
          hijri: HijriDate(month.year, month.month, d),
          date: first.add(Duration(days: d - 1)),
          isToday: today == HijriDate(month.year, month.month, d),
        ),
    ];
    while (cells.length % 7 != 0) {
      cells.add(const SizedBox.shrink());
    }
    return SenjaCard(
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    range,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.inkMuted,
                    ),
                  ),
                ),
                const _Legend(),
              ],
            ),
          ),
          Row(
            children: [
              for (final w in _weekdays)
                Expanded(
                  child: Text(
                    w,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: w == 'Jum'
                          ? AppColors.secondary
                          : AppColors.inkMuted,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          for (var r = 0; r < cells.length; r += 7)
            Row(
              children: [
                for (var c = r; c < r + 7; c++) Expanded(child: cells[c]),
              ],
            ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const _Dot(AppColors.gold),
        const SizedBox(width: 4),
        Text(
          'Hari besar',
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: AppColors.inkMuted,
          ),
        ),
        const SizedBox(width: 10),
        const _Dot(AppColors.secondary),
        const SizedBox(width: 4),
        Text(
          'Ayyamul bidh',
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: AppColors.inkMuted,
          ),
        ),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot(this.color);

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 6,
    height: 6,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    super.key,
    required this.hijri,
    required this.date,
    required this.isToday,
  });

  final HijriDate hijri;
  final DateTime date;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final event = eventOn(hijri);
    final bidh = isAyyamulBidh(hijri);
    final friday = date.weekday == DateTime.friday;
    final dot = event != null
        ? AppColors.gold
        : bidh
        ? AppColors.secondary
        : null;
    return Semantics(
      label: [
        '${hijri.day} ${hijri.monthName}',
        DateFormat('EEEE d MMMM', 'id_ID').format(date),
        if (isToday) 'hari ini',
        if (event != null) event.name,
        if (bidh) 'puasa ayyamul bidh',
      ].join(', '),
      child: ExcludeSemantics(
        child: Container(
          height: 48,
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: isToday ? AppColors.secondary : null,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${hijri.day}',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.1,
                  fontWeight: FontWeight.w800,
                  color: isToday
                      ? Colors.white
                      : friday
                      ? AppColors.secondary
                      : AppColors.ink,
                ),
              ),
              Text(
                '${date.day}',
                style: TextStyle(
                  fontSize: 9.5,
                  height: 1.2,
                  fontWeight: FontWeight.w600,
                  color: isToday
                      ? Colors.white.withValues(alpha: 0.8)
                      : AppColors.inkMuted,
                ),
              ),
              SizedBox(
                height: 6,
                child: dot == null
                    ? null
                    : Center(child: _Dot(isToday ? Colors.white : dot)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EventRow extends StatelessWidget {
  const _EventRow({required this.event, required this.divider});

  final UpcomingEvent event;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    final left = event.daysLeft;
    final when = left == 0
        ? 'Hari ini'
        : left == 1
        ? 'Besok'
        : '$left hari lagi';
    return Container(
      constraints: const BoxConstraints(minHeight: 60),
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: divider
            ? Border(bottom: BorderSide(color: AppColors.lilacLine))
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.goldSoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${event.hijri.day}',
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.1,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
                Text(
                  event.hijri.monthName.split(' ').first.substring(0, 3),
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.inkMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.event.name,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
                Text(
                  [
                    DateFormat('EEEE, d MMM yyyy', 'id_ID').format(event.date),
                    if (event.event.note != null) event.event.note!,
                  ].join(' · '),
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
          const SizedBox(width: 8),
          SenjaTag(when),
        ],
      ),
    );
  }
}
