import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:muslimku/core/theme/app_colors.dart';
import 'package:muslimku/core/time/clock_provider.dart';
import 'package:muslimku/features/calendar/application/hijri_provider.dart';
import 'package:muslimku/features/calendar/domain/hijri.dart';
import 'package:muslimku/features/calendar/presentation/hijri_calendar_screen.dart';
import 'package:muslimku/features/hadith/application/hadits_providers.dart';
import 'package:muslimku/features/hadith/domain/hadith_model.dart';
import 'package:muslimku/features/home/application/daily_content_provider.dart';
import 'package:muslimku/features/home/application/seen_features_provider.dart';
import 'package:muslimku/features/home/presentation/widgets/daily_cards.dart';
import 'package:muslimku/features/home/presentation/widgets/ibadah_grid.dart';
import 'package:muslimku/features/home/presentation/widgets/prayer_log_strip.dart';
import 'package:muslimku/features/home/presentation/widgets/prayer_timeline.dart';
import 'package:muslimku/features/location/application/location_provider.dart';
import 'package:muslimku/features/location/presentation/city_picker_sheet.dart';
import 'package:muslimku/features/prayer/application/prayer_time_provider.dart';
import 'package:muslimku/features/prayer/data/prayer_schedule_repository.dart';
import 'package:muslimku/features/prayer/domain/prayer_schedule.dart';
import 'package:muslimku/features/prayer/presentation/monthly_schedule_screen.dart';
import 'package:muslimku/features/prayer/presentation/prayer_log_screen.dart';
import 'package:muslimku/features/qibla/presentation/qibla_screen.dart';
import 'package:muslimku/features/settings/presentation/settings_screen.dart';
import 'package:muslimku/features/tasbih/presentation/tasbih_screen.dart';
import 'package:muslimku/shared/widgets/diorama/diorama_widgets.dart';

/// Tab indexes of [HomeScreen] that the Ibadah grid can jump to.
class HomeTabs {
  static const quran = 1;
  static const hadith = 2;
  static const asmaulHusna = 3;
  static const doa = 4;
}

/// "Diorama Senja" home: dusk stage with the floating mosque island and the
/// next prayer, then a white sheet with today's times, the Ibadah grid and the
/// daily content.
class HomeTab extends ConsumerStatefulWidget {
  const HomeTab({super.key, required this.onOpenTab});

  final ValueChanged<int> onOpenTab;

  @override
  ConsumerState<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends ConsumerState<HomeTab> {
  final _scroll = ScrollController();
  String? _lastCityId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPrayerTimes();
      _loadDailyContent();
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _loadPrayerTimes() async {
    final cityId = ref.read(locationProvider).cityId;
    await ref.read(prayerTimeProvider.notifier).loadPrayerTimes(cityId: cityId);
    if (!mounted || ref.read(prayerTimeProvider).fromSaved) return;
    // Keep this month on the phone so Beranda and adzan reminders work offline.
    final now = DateTime.now();
    unawaited(
      ref
          .read(prayerScheduleRepositoryProvider)
          .month(cityId, now.year, now.month)
          .then((_) {}, onError: (_) {}),
    );
  }

  Future<void> _loadDailyContent() async {
    // A failed Arbain list (first start without internet) is retried with
    // the other cards, so the card can show "Hadits hari ini" again.
    if (ref.read(arbainListProvider).hasError) {
      ref.invalidate(arbainListProvider);
    }
    try {
      await ref.read(dailyContentProvider.notifier).loadAllContent();
    } catch (_) {
      // The cards simply stay hidden.
    }
  }

  void _push(Widget page) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<LocationState>(locationProvider, (previous, next) {
      if (next.selectedCityId != null && next.selectedCityId != _lastCityId) {
        _lastCityId = next.selectedCityId;
        Future.microtask(_loadPrayerTimes);
      }
    });

    final media = MediaQuery.of(context);
    final topInset = media.padding.top;
    final width = media.size.width;
    final stageHeight = topInset + 438;

    final seen = ref.watch(seenFeaturesProvider);
    bool isNew(String feature) => seen != null && !seen.contains(feature);
    void openFeature(String feature, Widget page) {
      ref.read(seenFeaturesProvider.notifier).markSeen(feature);
      _push(page);
    }

    final items = [
      IbadahItem(
        label: "Al-Qur'an",
        icon: 'images/3d/icon_quran.webp',
        onTap: () => widget.onOpenTab(HomeTabs.quran),
      ),
      IbadahItem(
        label: 'Hadits',
        icon: 'images/3d/icon_hadits.webp',
        onTap: () => widget.onOpenTab(HomeTabs.hadith),
      ),
      IbadahItem(
        label: 'Doa',
        icon: 'images/3d/icon_doa.webp',
        onTap: () => widget.onOpenTab(HomeTabs.doa),
      ),
      IbadahItem(
        label: 'Asmaul Husna',
        icon: 'images/3d/icon_husna.webp',
        onTap: () => widget.onOpenTab(HomeTabs.asmaulHusna),
      ),
      IbadahItem(
        label: 'Kiblat',
        icon: 'images/3d/icon_kiblat.webp',
        onTap: () => _push(const QiblaScreen()),
      ),
      IbadahItem(
        label: 'Tasbih',
        icon: 'images/3d/icon_tasbih.webp',
        onTap: () => _push(const TasbihScreen()),
      ),
      IbadahItem(
        label: 'Kalender',
        icon: 'images/3d/icon_kalender.webp',
        isNew: isNew(SeenFeaturesNotifier.kalender),
        onTap: () => openFeature(
          SeenFeaturesNotifier.kalender,
          const HijriCalendarScreen(),
        ),
      ),
      IbadahItem(
        label: 'Catatan',
        icon: 'images/3d/icon_catatan.webp',
        isNew: isNew(SeenFeaturesNotifier.catatan),
        onTap: () =>
            openFeature(SeenFeaturesNotifier.catatan, const PrayerLogScreen()),
      ),
      IbadahItem(
        label: 'Jadwal',
        icon: 'images/3d/icon_jadwal.webp',
        isNew: isNew(SeenFeaturesNotifier.jadwal),
        onTap: () {
          final location = ref.read(locationProvider);
          final model = ref.read(prayerTimeProvider).prayerTime;
          openFeature(
            SeenFeaturesNotifier.jadwal,
            MonthlyScheduleScreen(
              cityId: location.cityId,
              city: titleCaseCity(model?.lokasi ?? location.cityName),
            ),
          );
        },
      ),
    ];

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: RefreshIndicator(
        color: AppColors.secondary,
        edgeOffset: topInset,
        onRefresh: () => Future.wait([_loadPrayerTimes(), _loadDailyContent()]),
        child: SingleChildScrollView(
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          child: Stack(
            children: [
              SizedBox(
                height: stageHeight,
                width: double.infinity,
                child: _Stage(topInset: topInset, width: width),
              ),
              // The island drifts a little slower than the page, so the sheet
              // slides over it when scrolling.
              Positioned(
                top: topInset + 126,
                right: -width * 0.1,
                width: (width * 0.67).clamp(220.0, 320.0),
                child: AnimatedBuilder(
                  animation: _scroll,
                  builder: (context, child) {
                    final offset = _scroll.hasClients ? _scroll.offset : 0.0;
                    return Transform.translate(
                      offset: Offset(0, offset.clamp(0.0, 400.0) * 0.25),
                      child: child,
                    );
                  },
                  child: FloatingArt(
                    child: Image.asset(
                      'images/3d/diorama_senja.webp',
                      fit: BoxFit.contain,
                      semanticLabel: 'Masjid di atas pulau melayang saat senja',
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.only(top: stageHeight - 42),
                child: _Sheet(items: items),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Stage extends ConsumerWidget {
  const _Stage({required this.topInset, required this.width});

  final double topInset;
  final double width;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prayer = ref.watch(prayerTimeProvider);
    final now = ref.watch(clockProvider).valueOrNull ?? DateTime.now();
    final location = ref.watch(locationProvider);
    final cityName = titleCaseCity(
      location.activeCityName ?? prayer.prayerTime?.lokasi ?? location.cityName,
    );
    final hijri = HijriDate.fromDate(
      now,
      adjust: ref.watch(hijriAdjustProvider),
    );
    final schedule = prayer.prayerTime?.jadwal;
    final next = schedule == null ? null : findNextPrayer(schedule, now);
    final scale = (width / 390).clamp(0.85, 1.1);

    return DuskSky(
      child: Stack(
        children: [
          Positioned(
            top: topInset + 66,
            right: 30,
            child: Transform.rotate(
              angle: -0.2,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFFD68C).withValues(alpha: 0.45),
                      blurRadius: 22,
                    ),
                  ],
                ),
                child: Image.asset(
                  'images/3d/moon.webp',
                  width: 42,
                  excludeFromSemantics: true,
                ),
              ),
            ),
          ),
          Positioned(
            top: topInset + 14,
            left: 20,
            child: _LocationPill(
              city: cityName,
              onTap: () => showCityPicker(context),
            ),
          ),
          Positioned(
            top: topInset + 12,
            right: 16,
            child: _GlassIconButton(
              icon: Icons.settings_outlined,
              tooltip: 'Pengaturan',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
              ),
            ),
          ),
          Positioned(
            top: topInset + 64,
            left: 24,
            right: 120,
            child: Semantics(
              button: true,
              label: 'Kalender Hijriah, ${hijri.label}',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const HijriCalendarScreen(),
                  ),
                ),
                child: ExcludeSemantics(
                  child: Text(
                    [
                      DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(now),
                      '${hijri.label} ›',
                    ].join('\n'),
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.5,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: topInset + 128,
            left: 24,
            child: _NextPrayerBlock(
              state: prayer,
              next: next,
              now: now,
              scale: scale,
              onRetry: () {
                final cityId = location.cityId;
                ref
                    .read(prayerTimeProvider.notifier)
                    .loadPrayerTimes(cityId: cityId);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: const Color(0x520F083C),
        shape: CircleBorder(
          side: BorderSide(color: Colors.white.withValues(alpha: 0.18)),
        ),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox.square(
            dimension: 40,
            child: Icon(icon, size: 21, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

class _LocationPill extends StatelessWidget {
  const _LocationPill({required this.city, required this.onTap});

  final String city;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Lokasi $city, ketuk untuk mengganti',
      excludeSemantics: true,
      child: Material(
        color: const Color(0x520F083C),
        shape: StadiumBorder(
          side: BorderSide(color: Colors.white.withValues(alpha: 0.18)),
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.location_on_rounded,
                  size: 18,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 200),
                  child: Text(
                    city,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
                const Icon(
                  Icons.expand_more_rounded,
                  size: 18,
                  color: Colors.white,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NextPrayerBlock extends StatelessWidget {
  const _NextPrayerBlock({
    required this.state,
    required this.next,
    required this.now,
    required this.scale,
    required this.onRetry,
  });

  final PrayerTimeState state;
  final NextPrayer? next;
  final DateTime now;
  final double scale;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final white70 = Colors.white.withValues(alpha: 0.72);
    if (next == null) {
      if (state.error != null && !state.isLoading) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Jadwal sholat\nbelum termuat',
              style: TextStyle(
                fontSize: 24,
                height: 1.2,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 14),
            _Pill(
              icon: Icons.refresh_rounded,
              label: 'Coba lagi',
              onTap: onRetry,
            ),
          ],
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'MEMUAT JADWAL…',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
              color: white70,
            ),
          ),
          const SizedBox(height: 12),
          for (final w in [110.0, 150.0])
            Container(
              width: w,
              height: 40,
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
        ],
      );
    }

    final n = next!;
    final countdown = countdownLabel(n.remaining(now));
    return Semantics(
      label:
          'Waktu berikutnya ${n.label}${n.isTomorrow ? ' besok' : ''} pukul ${n.time}, $countdown',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            n.isTomorrow ? 'BESOK' : 'WAKTU BERIKUTNYA',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
              color: white70,
            ),
          ),
          const SizedBox(height: 6),
          // Already display-sized (40-56 px): exempt from the phone's text
          // size so they never run into the island.
          Text(
            n.label,
            textScaler: TextScaler.noScaling,
            style: TextStyle(
              fontSize: 40 * scale,
              height: 1.05,
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
              color: Colors.white,
            ),
          ),
          Text(
            n.time,
            textScaler: TextScaler.noScaling,
            style: TextStyle(
              fontSize: 56 * scale,
              height: 1.0,
              fontWeight: FontWeight.w800,
              letterSpacing: -2,
              color: Colors.white,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 14),
          _Pill(icon: Icons.schedule_rounded, label: countdown),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label, this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(999),
        boxShadow: const [
          BoxShadow(color: Color(0x47140A50), offset: Offset(0, 6)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17, color: AppColors.ink),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return pill;
    return GestureDetector(onTap: onTap, child: pill);
  }
}

class _Sheet extends ConsumerWidget {
  const _Sheet({required this.items});

  final List<IbadahItem> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prayer = ref.watch(prayerTimeProvider);
    final now = ref.watch(clockProvider).valueOrNull ?? DateTime.now();
    final daily = ref.watch(dailyContentProvider);
    // The Arbain card is "Hadits hari ini" of the Hadits tab, so both show
    // the same hadith. The random one stays as a fallback when the Arbain
    // list cannot load (first start without internet).
    final todayArbain = ref.watch(dailyArbainProvider);
    final schedule = prayer.prayerTime?.jadwal;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(34)),
        boxShadow: [
          const BoxShadow(
            color: Color(0x1F1E1078),
            blurRadius: 30,
            offset: Offset(0, -10),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 26, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(
            'Jadwal hari ini',
            trailing: _MonthLink(
              imsak: schedule == null || schedule.imsak.isEmpty
                  ? null
                  : schedule.imsak,
              onTap: () {
                final location = ref.read(locationProvider);
                final model = prayer.prayerTime;
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => MonthlyScheduleScreen(
                      cityId: location.cityId,
                      city: titleCaseCity(model?.lokasi ?? location.cityName),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          if (schedule != null)
            PrayerTimeline(
              entries: homeTimeline(schedule),
              states: timelineStates(
                homeTimeline(schedule),
                now,
                findNextPrayer(schedule, now),
              ),
            )
          else
            Container(
              height: 62,
              decoration: BoxDecoration(
                color: AppColors.lilac,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          const SizedBox(height: 14),
          PrayerLogStrip(today: schedule, now: now),
          const SizedBox(height: 28),
          const SectionHeader('Ibadah'),
          const SizedBox(height: 14),
          IbadahGrid(items: items),
          const SizedBox(height: 30),
          const SectionHeader('Penyejuk hati untukmu'),
          const SizedBox(height: 14),
          if (daily.isLoading && daily.quranAyah == null)
            const DailyCardsSkeleton()
          else
            _DailyCards(
              daily,
              arbain: todayArbain.hasError
                  ? daily.hadithArbain
                  : todayArbain.valueOrNull?.toArbainModel(),
            ),
        ],
      ),
    );
  }
}

/// "Imsak 03:39 · Sebulan ›" at the right of "Jadwal hari ini"; opens the
/// month table.
class _MonthLink extends StatelessWidget {
  const _MonthLink({required this.imsak, required this.onTap});

  final String? imsak;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w700,
      color: AppColors.secondary,
    );
    return Semantics(
      button: true,
      label: 'Jadwal sebulan${imsak == null ? '' : ', imsak hari ini $imsak'}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: ExcludeSemantics(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (imsak != null) ...[
                  Text('Imsak $imsak', style: style),
                  Text(
                    '  ·  ',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.lilacLine,
                    ),
                  ),
                ],
                const Text('Sebulan', style: style),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: AppColors.secondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DailyCards extends StatelessWidget {
  const _DailyCards(this.daily, {this.arbain});

  final DailyContentState daily;

  /// Today's Arbain (see [dailyArbainProvider]).
  final HadithArbainModel? arbain;

  @override
  Widget build(BuildContext context) {
    final hasHadith =
        arbain != null ||
        daily.hadithBulughul != null ||
        daily.hadithPerawi != null;
    final duo = [
      if (daily.doa != null && daily.doa!.arab.isNotEmpty)
        DoaCard(doa: daily.doa!),
      if (daily.asmaulHusna != null) HusnaCard(husna: daily.asmaulHusna!),
    ];
    if (daily.quranAyah == null && !hasHadith && duo.isEmpty) {
      return Text(
        'Konten harian belum termuat. Tarik layar ke bawah untuk mencoba lagi.',
        style: TextStyle(
          fontSize: 13.5,
          height: 1.5,
          color: AppColors.inkMuted,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (daily.quranAyah != null) ...[
          AyahCard(ayah: daily.quranAyah!),
          const SizedBox(height: 20),
        ],
        if (hasHadith) ...[
          HadithCard(
            arbain: arbain,
            bulughul: daily.hadithBulughul,
            perawi: daily.hadithPerawi,
          ),
          const SizedBox(height: 16),
        ],
        if (duo.length == 2)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 5, child: duo[0]),
                const SizedBox(width: 12),
                Expanded(flex: 4, child: duo[1]),
              ],
            ),
          )
        else if (duo.length == 1)
          duo.first,
      ],
    );
  }
}
