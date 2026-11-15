import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:muslimku/core/theme/app_colors.dart';
import 'package:muslimku/core/theme/app_text_styles.dart';
import 'package:muslimku/core/time/clock_provider.dart';
import 'package:muslimku/features/prayer/application/prayer_offsets_provider.dart';
import 'package:muslimku/features/prayer/data/prayer_schedule_repository.dart';
import 'package:muslimku/features/prayer/domain/prayer_schedule.dart'
    show titleCaseCity;
import 'package:muslimku/features/prayer/domain/prayer_time_model.dart';
import 'package:muslimku/shared/widgets/senja/senja.dart';
import 'package:share_plus/share_plus.dart';

/// One month of prayer times for [cityId], one row per day; works offline
/// for months already saved (the Beranda saves the current month).
///
/// Months come through [PrayerScheduleRepository.month], which keeps them on
/// the phone and serves the saved copy when offline, so flipping back and
/// forth does not refetch.
final monthScheduleProvider = FutureProvider.autoDispose
    .family<PrayerMonth, (String, int, int)>((ref, key) async {
      final (cityId, year, month) = key;
      final offsets = ref.watch(prayerOffsetsProvider);
      final raw = await ref
          .watch(prayerScheduleRepositoryProvider)
          .month(cityId, year, month);
      if (offsets.isZero) return raw;
      return PrayerMonth(
        cityId: raw.cityId,
        city: raw.city,
        region: raw.region,
        days: [for (final d in raw.days) offsets.apply(d)],
      );
    });

/// The month as plain text for sharing (monospace-friendly columns).
String monthScheduleText(PrayerMonth month, DateTime of) {
  final title = DateFormat('MMMM yyyy', 'id_ID').format(of);
  final city = titleCaseCity(month.city);
  final b = StringBuffer()
    ..writeln('Jadwal sholat $city · $title')
    ..writeln()
    ..writeln('Tgl  Imsak Subuh Dzuhur Ashar Maghrib Isya');
  for (final d in month.days) {
    final date = DateTime.tryParse(d.date);
    final day = (date?.day ?? 0).toString().padLeft(2);
    b.writeln(
      '$day   ${d.imsak} ${d.subuh} ${d.dzuhur}  ${d.ashar} ${d.maghrib}   ${d.isya}',
    );
  }
  b
    ..writeln()
    ..write('Sumber: MyQuran · Muslimku');
  return b.toString();
}

class MonthlyScheduleScreen extends ConsumerStatefulWidget {
  const MonthlyScheduleScreen({
    super.key,
    required this.cityId,
    required this.city,
    this.initialMonth,
  });

  final String cityId;

  /// Display name, e.g. "Kota Kediri".
  final String city;

  /// Defaults to the current month.
  final DateTime? initialMonth;

  @override
  ConsumerState<MonthlyScheduleScreen> createState() =>
      _MonthlyScheduleScreenState();
}

class _MonthlyScheduleScreenState extends ConsumerState<MonthlyScheduleScreen> {
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    final start = widget.initialMonth ?? ref.read(nowProvider)();
    _month = DateTime(start.year, start.month);
  }

  void _flip(int by) =>
      setState(() => _month = DateTime(_month.year, _month.month + by));

  Future<void> _share(PrayerMonth month) async {
    await SharePlus.instance.share(
      ShareParams(text: monthScheduleText(month, _month)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final key = (widget.cityId, _month.year, _month.month);
    final month = ref.watch(monthScheduleProvider(key));
    final now = ref.watch(clockProvider).valueOrNull ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final top = MediaQuery.paddingOf(context).top;
    final bottom = MediaQuery.paddingOf(context).bottom;
    final monthLabel = DateFormat('MMMM yyyy', 'id_ID').format(_month);
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
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(16, top + 4, 16, 0),
                sliver: SliverList.list(
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
                        SenjaIconButton(
                          icon: Icons.ios_share_rounded,
                          tooltip: 'Bagikan jadwal',
                          iconSize: 22,
                          onPressed: month.valueOrNull == null
                              ? null
                              : () => _share(month.value!),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(6, 8, 6, 2),
                      child: Semantics(
                        header: true,
                        child: Text(
                          'Jadwal sebulan',
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
                        widget.city,
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.3,
                          fontWeight: FontWeight.w600,
                          color: AppColors.inkMuted,
                        ),
                      ),
                    ),
                    SenjaMonthBar(
                      label: monthLabel,
                      onPrevious: () => _flip(-1),
                      onNext: () => _flip(1),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
              month.when(
                skipLoadingOnRefresh: false,
                data: (data) => SliverPadding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, bottom + 28),
                  sliver: SliverToBoxAdapter(
                    child: _MonthTable(month: data, today: today),
                  ),
                ),
                loading: () => const SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverToBoxAdapter(child: SenjaSkeletonList(rows: 8)),
                ),
                error: (_, _) => SliverFillRemaining(
                  hasScrollBody: false,
                  child: SenjaEmptyState(
                    image: 'images/3d/moon.webp',
                    badgeIcon: Icons.wifi_off_rounded,
                    title: 'Jadwal belum tersimpan',
                    message:
                        'Jadwal $monthLabel belum ada di HP. Buka sekali saat '
                        'ada internet, setelah itu bisa dilihat kapan saja.',
                    primaryLabel: 'Coba lagi',
                    onPrimary: () => ref.invalidate(monthScheduleProvider(key)),
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

/// "‹  Oktober 2026  ›" on a white card.
class _MonthTable extends StatelessWidget {
  const _MonthTable({required this.month, required this.today});

  final PrayerMonth month;
  final DateTime today;

  static const _columns = [
    'Imsak',
    'Subuh',
    'Dzuhur',
    'Ashar',
    'Maghrib',
    'Isya',
  ];

  static List<String> _times(PrayerSchedule d) => [
    d.imsak,
    d.subuh,
    d.dzuhur,
    d.ashar,
    d.maghrib,
    d.isya,
  ];

  @override
  Widget build(BuildContext context) {
    return SenjaCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          const _TableRow(day: 'Tgl', cells: _columns, header: true),
          for (final d in month.days)
            _DayRow(
              schedule: d,
              times: _times(d),
              today: d.date == _iso(today),
              last: d == month.days.last,
            ),
        ],
      ),
    );
  }

  static String _iso(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

class _DayRow extends StatelessWidget {
  const _DayRow({
    required this.schedule,
    required this.times,
    required this.today,
    required this.last,
  });

  final PrayerSchedule schedule;
  final List<String> times;
  final bool today;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final date = DateTime.tryParse(schedule.date);
    final dayNumber = date == null ? '' : '${date.day}';
    final weekday = date == null ? '' : DateFormat('EEE', 'id_ID').format(date);
    final friday = date?.weekday == DateTime.friday;
    final label = date == null
        ? schedule.date
        : DateFormat('EEEE d MMMM', 'id_ID').format(date);
    return Semantics(
      key: ValueKey('day-${schedule.date}'),
      label:
          '$label${today ? ', hari ini' : ''}. '
          'Imsak ${schedule.imsak}, Subuh ${schedule.subuh}, '
          'Dzuhur ${schedule.dzuhur}, Ashar ${schedule.ashar}, '
          'Maghrib ${schedule.maghrib}, Isya ${schedule.isya}',
      excludeSemantics: true,
      child: _TableRow(
        day: dayNumber,
        weekday: weekday,
        cells: times,
        highlight: today,
        emphasis: friday,
        divider: !last,
      ),
    );
  }
}

class _TableRow extends StatelessWidget {
  const _TableRow({
    required this.day,
    required this.cells,
    this.weekday,
    this.header = false,
    this.highlight = false,
    this.emphasis = false,
    this.divider = true,
  });

  final String day;
  final String? weekday;
  final List<String> cells;
  final bool header;
  final bool highlight;

  /// Friday: the day number in purple.
  final bool emphasis;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    final muted = header ? AppColors.inkMuted : AppColors.ink;
    final cellStyle = TextStyle(
      fontSize: header ? 11 : 12.5,
      fontWeight: header ? FontWeight.w800 : FontWeight.w600,
      letterSpacing: header ? 0.2 : 0,
      color: highlight ? AppColors.secondary : muted,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return Container(
      constraints: const BoxConstraints(minHeight: 40),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: highlight ? AppColors.lilac : null,
        borderRadius: highlight ? BorderRadius.circular(12) : null,
        border: divider && !highlight
            ? Border(bottom: BorderSide(color: AppColors.lilacLine))
            : null,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: header
                ? Text(day, style: cellStyle)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        day,
                        style: cellStyle.copyWith(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: highlight || emphasis
                              ? AppColors.secondary
                              : AppColors.ink,
                        ),
                      ),
                      if (weekday != null)
                        Text(
                          weekday!,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.inkMuted,
                          ),
                        ),
                    ],
                  ),
          ),
          for (final cell in cells)
            Expanded(
              // Shrinks rather than clips at large text sizes ("Maghrib").
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  cell,
                  textAlign: TextAlign.center,
                  style: cellStyle,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
