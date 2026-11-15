import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:muslimku/core/theme/app_colors.dart';
import 'package:muslimku/core/theme/app_theme_provider.dart';
import 'package:muslimku/features/calendar/application/hijri_provider.dart';
import 'package:muslimku/features/calendar/domain/hijri.dart';
import 'package:muslimku/features/calendar/presentation/hijri_calendar_screen.dart';
import 'package:muslimku/features/location/application/device_city_provider.dart';
import 'package:muslimku/features/location/application/location_provider.dart';
import 'package:muslimku/features/location/presentation/city_picker_sheet.dart';
import 'package:muslimku/features/prayer/application/adzan_provider.dart';
import 'package:muslimku/features/prayer/application/prayer_offsets_provider.dart';
import 'package:muslimku/features/prayer/application/prayer_time_provider.dart';
import 'package:muslimku/features/prayer/data/prayer_schedule_repository.dart';
import 'package:muslimku/features/prayer/domain/adzan_plan.dart';
import 'package:muslimku/features/prayer/domain/prayer_schedule.dart';
import 'package:muslimku/features/quran/application/murottal_download_provider.dart';
import 'package:muslimku/features/quran/data/quran_repository.dart';
import 'package:muslimku/features/quran/presentation/reader/reciter_sheet.dart';
import 'package:muslimku/features/reading/application/reading_settings_provider.dart';
import 'package:muslimku/features/settings/presentation/adzan_sound_sheet.dart';
import 'package:muslimku/features/settings/presentation/extra_reminders_sheet.dart';
import 'package:muslimku/features/settings/presentation/privacy_policy_screen.dart';
import 'package:muslimku/features/settings/presentation/reminder_check_screen.dart';
import 'package:muslimku/features/settings/presentation/settings_sheets.dart';
import 'package:muslimku/shared/application/offline_data_provider.dart';
import 'package:muslimku/shared/widgets/senja/senja.dart';

/// Pengaturan (design-v2 s1): city, adzan reminders, reading look and data
/// saved for offline use. Everything stays on the phone.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Back from the system settings (notification or exact alarm permission).
    if (state == AppLifecycleState.resumed) {
      ref.read(adzanProvider.notifier).reschedule();
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final bottom = MediaQuery.paddingOf(context).bottom;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: AppColors.stageBackground,
        body: ListView(
          padding: EdgeInsets.fromLTRB(16, top + 4, 16, bottom + 28),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: SenjaIconButton(
                icon: Icons.arrow_back_rounded,
                tooltip: 'Kembali',
                iconSize: 24,
                onPressed: () => Navigator.maybePop(context),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 8, 6, 6),
              child: Text(
                'Pengaturan',
                style: TextStyle(
                  fontSize: 30,
                  letterSpacing: -0.6,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
            ),
            const _Label('Lokasi & jadwal'),
            _LocationGroup(onMessage: _toast),
            const _Label('Pengingat adzan'),
            const _AdzanGroup(),
            const _Label('Tampilan'),
            const _LookGroup(),
            const _Label('Data offline'),
            _OfflineGroup(onMessage: _toast),
            const _Label('Tentang'),
            _Group(
              children: [
                const _Row(
                  icon: Icons.info_outline_rounded,
                  title: 'Sumber data',
                  subtitle:
                      'Jadwal, Al-Qur\'an, tema, hadits, doa: MyQuran. Tafsir '
                      'Kemenag: equran.id. Tajwid: alquran.cloud. Murottal: '
                      'cdn.islamic.network. '
                      'Koordinat kota: Wikidata. Rekaman adzan: Adam-synagda '
                      '(Wikimedia Commons, CC0).',
                ),
                _Row(
                  icon: Icons.privacy_tip_outlined,
                  title: 'Kebijakan privasi',
                  subtitle:
                      'Tanpa akun dan tanpa iklan. Datamu tersimpan di HP.',
                  trailing: const _Chevron(),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const PrivacyPolicyScreen(),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LocationGroup extends ConsumerWidget {
  const _LocationGroup({required this.onMessage});

  final ValueChanged<String> onMessage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = ref.watch(locationProvider);
    final device = ref.watch(deviceCityProvider);
    final offsets = ref.watch(prayerOffsetsProvider);
    final hijriAdjust = ref.watch(hijriAdjustProvider);
    final hijriToday = HijriDate.fromDate(DateTime.now(), adjust: hijriAdjust);
    final cityId = location.cityId;
    final city = titleCaseCity(location.cityName);
    final fromDevice =
        device.deviceCityId != null &&
        device.deviceCityId == location.activeCityId;
    return _Group(
      children: [
        _Row(
          icon: Icons.location_on_outlined,
          title: 'Kota',
          subtitle:
              '$city · ${location.activeCityId == null
                  ? 'bawaan'
                  : fromDevice
                  ? 'dari lokasi HP'
                  : 'dipilih manual'}',
          trailing: const _Chevron(),
          onTap: () => showCityPicker(context),
          semanticsHint: 'Ganti kota $cityId',
        ),
        _Row(
          icon: Icons.my_location_rounded,
          title: 'Pakai lokasi saya',
          subtitle: 'Kota terdekat dihitung di HP, tidak dikirim',
          trailing: SenjaSmallButton(
            label: device.busy ? 'Mencari…' : 'Pakai',
            onTap: device.busy
                ? null
                : () async => onMessage(
                    await ref
                        .read(deviceCityProvider.notifier)
                        .useDeviceLocation(),
                  ),
          ),
        ),
        _Row(
          icon: Icons.tune_rounded,
          title: 'Koreksi waktu sholat',
          subtitle: offsets.summary,
          trailing: const _Chevron(),
          onTap: () => showPrayerOffsetSheet(context),
        ),
        _Row(
          icon: Icons.calendar_month_rounded,
          title: 'Koreksi tanggal Hijriah',
          subtitle: switch (hijriAdjust) {
            1 => '+1 hari · ${hijriToday.label}',
            -1 => '−1 hari · ${hijriToday.label}',
            _ => 'Sesuai hisab · ${hijriToday.label}',
          },
          trailing: const _Chevron(),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const HijriCalendarScreen(),
            ),
          ),
        ),
      ],
    );
  }
}

class _AdzanGroup extends ConsumerWidget {
  const _AdzanGroup();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final adzan = ref.watch(adzanProvider);
    final notifier = ref.read(adzanProvider.notifier);
    final today = ref.watch(prayerTimeProvider).prayerTime?.jadwal;
    final s = adzan.settings;
    final String? note = adzan.notificationsDenied
        ? 'Izin notifikasi ditolak. Izinkan lewat pengaturan HP.'
        : adzan.message ??
              (s.enabled && !adzan.exactAllowed
                  ? 'Pengingat bisa terlambat beberapa menit. Izinkan alarm tepat waktu.'
                  : null);
    return _Group(
      children: [
        _Row(
          icon: Icons.notifications_none_rounded,
          title: 'Pengingat adzan',
          subtitle: s.enabled && adzan.scheduled > 0
              ? 'Aktif · ${adzan.scheduled} pengingat 14 hari ke depan'
              : 'Notifikasi di HP, tanpa internet',
          trailing: SenjaSwitch(
            value: s.enabled,
            onChanged: notifier.setEnabled,
          ),
        ),
        if (s.enabled) ...[
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.lilacLine)),
            ),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final prayer in AdzanPrayer.values)
                  _PrayerChip(
                    label: prayer.label,
                    time: today == null ? null : prayer.timeIn(today),
                    selected: s.prayers.contains(prayer),
                    onTap: () => notifier.togglePrayer(prayer),
                  ),
              ],
            ),
          ),
          _Row(
            icon: Icons.schedule_rounded,
            title: 'Ingatkan 10 menit sebelumnya',
            subtitle: 'Supaya sempat bersiap',
            trailing: SenjaSwitch(
              value: s.remindBefore,
              onChanged: notifier.setRemindBefore,
            ),
          ),
          _Row(
            icon: Icons.wb_twilight_rounded,
            title: 'Pengingat sahur',
            subtitle: '45 menit sebelum Imsak · untuk hari puasa',
            trailing: SenjaSwitch(value: s.sahur, onChanged: notifier.setSahur),
          ),
          _Row(
            icon: Icons.notifications_active_outlined,
            title: 'Pengingat lainnya',
            subtitle: extraRemindersSummary(s.extras),
            trailing: const _Chevron(),
            onTap: () => showExtraRemindersSheet(context),
          ),
          _Row(
            icon: Icons.volume_up_rounded,
            title: 'Suara pengingat',
            subtitle: '${s.sound.label} · ${s.sound.description}',
            trailing: const _Chevron(),
            onTap: () => showAdzanSoundSheet(context),
          ),
          _Row(
            icon: Icons.fact_check_outlined,
            title: 'Cek pengingat',
            subtitle: 'Izin, penghemat baterai, dan coba bunyikan',
            trailing: const _Chevron(),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const ReminderCheckScreen(),
              ),
            ),
          ),
        ],
        if (note != null)
          _Note(
            text: note,
            action: adzan.notificationsDenied
                ? 'Buka pengaturan HP'
                : (s.enabled && !adzan.exactAllowed && adzan.message == null)
                ? 'Izinkan'
                : adzan.message != null
                ? 'Coba lagi'
                : null,
            onAction: () {
              if (adzan.notificationsDenied) {
                Geolocator.openAppSettings();
              } else if (adzan.message != null) {
                notifier.reschedule();
              } else {
                notifier.requestExactAlarms();
              }
            },
          ),
      ],
    );
  }
}

class _LookGroup extends ConsumerWidget {
  const _LookGroup();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(readingSettingsProvider);
    final appTheme = ref.watch(appThemeProvider);
    return _Group(
      children: [
        _Row(
          icon: Icons.brightness_6_outlined,
          title: 'Tema aplikasi',
          subtitle: appTheme.label,
          trailing: const _Chevron(),
          onTap: () => showAppThemeSheet(context),
        ),
        _Row(
          icon: Icons.dark_mode_outlined,
          title: 'Tema bacaan',
          subtitle: s.autoNight
              ? '${s.theme.label} · malam setelah Maghrib'
              : s.theme.label,
          trailing: const _Chevron(),
          onTap: () => showReadingThemeSheet(context),
        ),
        _Row(
          icon: Icons.text_fields_rounded,
          title: 'Ukuran huruf Arab',
          subtitle: '${s.arabicSize.round()} · ikut juga ukuran huruf HP',
          trailing: const _Chevron(),
          onTap: () => showArabicSizeSheet(context),
        ),
        _Row(
          icon: Icons.record_voice_over_rounded,
          title: 'Qari murottal',
          subtitle: s.reciter.label,
          trailing: const _Chevron(),
          onTap: () => showReciterSheet(context),
        ),
      ],
    );
  }
}

class _OfflineGroup extends ConsumerWidget {
  const _OfflineGroup({required this.onMessage});

  final ValueChanged<String> onMessage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quran = ref.watch(quranDownloadProvider);
    final lists = ref.watch(offlineListsProvider);
    final murottal = ref.watch(murottalTotalsProvider);
    final location = ref.watch(locationProvider);
    final now = DateTime.now();
    final cityId = location.cityId;
    final month = ref.watch(_savedMonthProvider((cityId, now.year, now.month)));
    final monthName = DateFormat('MMMM', 'id_ID').format(now);
    final quranSize = quran.storedBytes == 0
        ? '±6 MB'
        : '${formatBytes(quran.storedBytes)} dari ±6 MB';
    return _Group(
      children: [
        _Row(
          icon: Icons.menu_book_rounded,
          title: 'Al-Qur\'an',
          subtitle: quran.running
              ? 'Mengunduh… ${quran.storedSurahs}/114 surat'
              : '${quran.storedSurahs}/114 surat · $quranSize',
          trailing: SenjaSmallButton(
            label: quran.running
                ? 'Batal'
                : quran.complete
                ? 'Hapus'
                : 'Unduh',
            onTap: () {
              final n = ref.read(quranDownloadProvider.notifier);
              if (quran.running) {
                n.cancel();
              } else if (quran.complete) {
                n.deleteAll();
              } else {
                n.start();
              }
            },
          ),
          below: quran.running || quran.error != null
              ? Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: quran.error != null
                      ? Text(quran.error!, style: _noteStyle)
                      : SenjaProgressBar(value: quran.progress),
                )
              : null,
        ),
        _Row(
          icon: Icons.favorite_border_rounded,
          title: 'Doa, Hadits, Asmaul Husna',
          subtitle: lists.busy
              ? 'Menyimpan…'
              : lists.complete
              ? 'Tersimpan · ${formatBytes(lists.bytes)}'
              : lists.saved == 0
              ? 'Belum tersimpan · ±200 KB'
              : 'Sebagian tersimpan · ${formatBytes(lists.bytes)}',
          trailing: SenjaSmallButton(
            label: lists.complete ? 'Perbarui' : 'Simpan',
            onTap: lists.busy
                ? null
                : () async {
                    await ref.read(offlineListsProvider.notifier).saveAll();
                    final error = ref.read(offlineListsProvider).error;
                    onMessage(
                      error ?? 'Doa, hadits, dan Asmaul Husna tersimpan di HP.',
                    );
                  },
          ),
        ),
        _Row(
          icon: Icons.headphones_rounded,
          title: 'Murottal tersimpan',
          subtitle: switch (murottal.valueOrNull) {
            null => 'Menghitung…',
            (0, _) => 'Belum ada',
            (final n, final bytes) => '$n ayat · ${formatBytes(bytes)}',
          },
          semanticsHint: 'Lihat dan hapus murottal yang tersimpan',
          onTap: () => _showMurottalStorageSheet(context, ref),
        ),
        _Row(
          icon: Icons.event_available_rounded,
          title: 'Jadwal sholat $monthName',
          subtitle: month.valueOrNull == true
              ? 'Tersimpan · Beranda tetap jalan tanpa internet'
              : 'Belum tersimpan',
          trailing: SenjaSmallButton(
            label: month.valueOrNull == true ? 'Perbarui' : 'Simpan',
            onTap: () async {
              try {
                await ref
                    .read(prayerScheduleRepositoryProvider)
                    .month(cityId, now.year, now.month);
                ref.invalidate(_savedMonthProvider);
                onMessage('Jadwal sholat $monthName tersimpan.');
              } catch (_) {
                onMessage(
                  'Belum bisa menyimpan jadwal. Coba lagi saat ada internet.',
                );
              }
            },
          ),
        ),
      ],
    );
  }
}

final _savedMonthProvider = FutureProvider.autoDispose
    .family<bool, (String, int, int)>(
      (ref, key) async =>
          await ref
              .watch(prayerScheduleRepositoryProvider)
              .savedMonth(key.$1, key.$2, key.$3) !=
          null,
    );

const _noteStyle = TextStyle(
  fontSize: 12,
  height: 1.4,
  fontWeight: FontWeight.w600,
  color: AppColors.offlineAccent,
);

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 18, 6, 8),
      child: Semantics(
        header: true,
        child: Text(
          text.toUpperCase(),
          style: TextStyle(
            fontSize: 11.5,
            letterSpacing: 1.1,
            fontWeight: FontWeight.w800,
            color: AppColors.inkMuted,
          ),
        ),
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.lilacLine, width: 1.5),
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++)
            if (i == children.length - 1 || children[i] is! _Row)
              children[i]
            else
              DecoratedBox(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: AppColors.lilacLine),
                  ),
                ),
                child: children[i],
              ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
    this.below,
    this.semanticsHint,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Widget? below;
  final String? semanticsHint;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      hint: semanticsHint,
      child: InkWell(
        onTap: onTap,
        child: Column(
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 62),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.lilac,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, size: 19, color: AppColors.secondary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
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
                              fontSize: 11.5,
                              height: 1.35,
                              fontWeight: FontWeight.w600,
                              color: AppColors.inkMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: 10),
                    trailing!,
                  ],
                ],
              ),
            ),
            if (below != null) below!,
          ],
        ),
      ),
    );
  }
}

class _Chevron extends StatelessWidget {
  const _Chevron();

  @override
  Widget build(BuildContext context) =>
      Icon(Icons.chevron_right_rounded, size: 22, color: AppColors.inkMuted);
}

class _PrayerChip extends StatelessWidget {
  const _PrayerChip({
    required this.label,
    required this.time,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String? time;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: 'Pengingat $label',
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 11),
          decoration: BoxDecoration(
            color: selected ? AppColors.lilac : AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.lilacShadow : AppColors.lilacLine,
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                selected
                    ? Icons.notifications_active_rounded
                    : Icons.notifications_off_outlined,
                size: 15,
                color: selected ? AppColors.secondary : AppColors.inkMuted,
              ),
              const SizedBox(width: 6),
              Text.rich(
                TextSpan(
                  text: label,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                  children: [
                    if (time != null)
                      TextSpan(
                        text: ' $time',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                  ],
                ),
                style: TextStyle(
                  fontSize: 12,
                  // ayahDeep is near-black: unreadable on the night chip.
                  color: selected
                      ? (AppColors.dark ? AppColors.ink : AppColors.ayahDeep)
                      : AppColors.inkMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.text, this.action, this.onAction});

  final String text;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: AppColors.offlineAccent,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: _noteStyle)),
          if (action != null) ...[
            const SizedBox(width: 8),
            SenjaSmallButton(label: action!, onTap: onAction),
          ],
        ],
      ),
    );
  }
}

Future<void> _showMurottalStorageSheet(BuildContext context, WidgetRef ref) {
  return showSenjaSheet<void>(
    context,
    title: 'Murottal tersimpan',
    builder: (context) => Consumer(
      builder: (context, ref, _) {
        final totals = ref.watch(murottalTotalsProvider).valueOrNull;
        final (count, bytes) = totals ?? (0, 0);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              count == 0 ? 'Belum ada' : '$count ayat · ${formatBytes(bytes)}',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Murottal diunduh per surat dari halaman baca (Murottal '
              'offline), terpisah untuk tiap qari.',
              style: _noteStyle,
            ),
            const SizedBox(height: 14),
            SenjaButton(
              label: 'Hapus semua murottal',
              icon: Icons.delete_outline_rounded,
              height: 48,
              onPressed: count == 0
                  ? null
                  : () =>
                        ref.read(murottalDownloadProvider.notifier).deleteAll(),
            ),
          ],
        );
      },
    ),
  );
}
