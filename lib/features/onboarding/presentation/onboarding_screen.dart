import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muslimku/core/theme/app_colors.dart';
import 'package:muslimku/core/theme/app_text_styles.dart';
import 'package:muslimku/features/location/application/device_city_provider.dart';
import 'package:muslimku/features/location/application/location_provider.dart';
import 'package:muslimku/features/location/presentation/city_picker_sheet.dart';
import 'package:muslimku/features/prayer/application/adzan_provider.dart';
import 'package:muslimku/features/prayer/domain/prayer_schedule.dart'
    show titleCaseCity;
import 'package:muslimku/features/settings/presentation/adzan_sound_sheet.dart'
    show AdzanSoundSheet;
import 'package:muslimku/shared/widgets/senja/senja.dart';
import 'package:shared_preferences/shared_preferences.dart';

const onboardingDoneKey = 'onboarding_done';

/// A fresh install sees the onboarding once. Anyone with a saved city (every
/// user since 1.0.1) skips it.
Future<bool> needsOnboarding() async {
  final prefs = await SharedPreferences.getInstance();
  if (prefs.getBool(onboardingDoneKey) ?? false) return false;
  return prefs.getString('selectedCityId') == null;
}

Future<void> markOnboardingDone() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(onboardingDoneKey, true);
}

/// Three steps before the first Beranda: city, adzan reminders, sound. Each
/// step writes through the same providers Pengaturan uses, so nothing here
/// is a second source of truth.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  int _step = 0;
  String? _message;

  static const _steps = 3;

  Future<void> _finish() async {
    await markOnboardingDone();
    if (mounted) widget.onDone();
  }

  Future<void> _useDevice() async {
    final message = await ref
        .read(deviceCityProvider.notifier)
        .useDeviceLocation();
    if (mounted) setState(() => _message = message);
  }

  Future<void> _enableReminders() async {
    await ref.read(adzanProvider.notifier).setEnabled(true);
    if (!mounted) return;
    if (ref.read(adzanProvider).notificationsDenied) {
      setState(
        () => _message =
            'Izin notifikasi ditolak. Bisa dinyalakan nanti di Pengaturan.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final bottom = MediaQuery.paddingOf(context).bottom;
    final location = ref.watch(locationProvider);
    final device = ref.watch(deviceCityProvider);
    final adzan = ref.watch(adzanProvider);
    final remindersOn = adzan.settings.enabled;
    final (title, lead) = switch (_step) {
      0 => (
        'Kota kamu',
        'Jadwal sholat dan arah kiblat dihitung dari kota ini. Lokasi hanya '
            'dipakai di HP untuk memilih kota terdekat.',
      ),
      1 => (
        'Pengingat adzan',
        'Notifikasi saat masuk waktu sholat, tanpa internet. Bisa diatur '
            'per waktu, dengan suara pilihanmu.',
      ),
      _ => (
        'Suara pengingat',
        'Dengarkan contohnya dulu. Bisa diganti kapan saja di Pengaturan.',
      ),
    };
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
            height: 1.45,
            fontWeight: FontWeight.w500,
            color: AppColors.ink,
          ),
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: EdgeInsets.fromLTRB(20, top + 24, 20, 12),
                  children: [
                    Row(
                      children: [
                        for (var i = 0; i < _steps; i++) ...[
                          if (i > 0) const SizedBox(width: 6),
                          Expanded(
                            child: Container(
                              height: 5,
                              decoration: BoxDecoration(
                                color: i <= _step
                                    ? AppColors.secondary
                                    : AppColors.lilacLine,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Langkah ${_step + 1} dari $_steps',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.secondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Semantics(
                      header: true,
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 30,
                          height: 1.15,
                          letterSpacing: -0.6,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      lead,
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.5,
                        fontWeight: FontWeight.w500,
                        color: AppColors.inkMuted,
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (_step == 0)
                      _CityStep(
                        city: titleCaseCity(location.cityName),
                        chosen: location.activeCityId != null,
                        busy: device.busy,
                        onUseDevice: _useDevice,
                        onPick: () => showCityPicker(context),
                      )
                    else if (_step == 1)
                      _ReminderStep(
                        on: remindersOn,
                        busy: adzan.busy,
                        onEnable: _enableReminders,
                      )
                    else
                      const SenjaCard(child: AdzanSoundSheet()),
                    if (_message != null) ...[
                      const SizedBox(height: 12),
                      SenjaCard(
                        color: AppColors.lilac,
                        child: Text(
                          _message!,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(20, 8, 20, bottom + 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_step < _steps - 1)
                      SenjaButton(
                        label: 'Lanjut',
                        icon: Icons.arrow_forward_rounded,
                        onPressed: () => setState(() {
                          _message = null;
                          // Without reminders there is no sound to choose.
                          _step = _step == 1 && !remindersOn
                              ? _steps
                              : _step + 1;
                          if (_step >= _steps) _finish();
                        }),
                      )
                    else
                      SenjaButton(label: 'Mulai', onPressed: _finish),
                    if (_step == 1 && !remindersOn) ...[
                      const SizedBox(height: 8),
                      SenjaButton(
                        label: 'Nanti saja',
                        style: SenjaButtonStyle.outline,
                        height: 48,
                        onPressed: _finish,
                      ),
                    ],
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

class _CityStep extends StatelessWidget {
  const _CityStep({
    required this.city,
    required this.chosen,
    required this.busy,
    required this.onUseDevice,
    required this.onPick,
  });

  final String city;
  final bool chosen;
  final bool busy;
  final VoidCallback onUseDevice;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return SenjaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.lilac,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.location_on_rounded,
                  color: AppColors.secondary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      city,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                    Text(
                      chosen
                          ? 'Kota pilihanmu'
                          : 'Kota bawaan sampai kamu memilih',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SenjaButton(
            label: busy ? 'Mencari lokasi…' : 'Pakai lokasi saya',
            icon: Icons.my_location_rounded,
            height: 48,
            onPressed: busy ? null : onUseDevice,
          ),
          const SizedBox(height: 8),
          SenjaButton(
            label: 'Pilih kota',
            icon: Icons.search_rounded,
            style: SenjaButtonStyle.outline,
            height: 48,
            onPressed: onPick,
          ),
        ],
      ),
    );
  }
}

class _ReminderStep extends StatelessWidget {
  const _ReminderStep({
    required this.on,
    required this.busy,
    required this.onEnable,
  });

  final bool on;
  final bool busy;
  final VoidCallback onEnable;

  @override
  Widget build(BuildContext context) {
    return SenjaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: on ? AppColors.secondary : AppColors.lilac,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  on
                      ? Icons.notifications_active_rounded
                      : Icons.notifications_none_rounded,
                  color: on ? Colors.white : AppColors.secondary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  on ? 'Pengingat aktif' : 'Pengingat belum aktif',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Android akan meminta izin notifikasi. Subuh, Dzuhur, Ashar, '
            'Maghrib, dan Isya, plus 10 menit sebelumnya.',
            style: TextStyle(
              fontSize: 12.5,
              height: 1.45,
              fontWeight: FontWeight.w600,
              color: AppColors.inkMuted,
            ),
          ),
          if (!on) ...[
            const SizedBox(height: 14),
            SenjaButton(
              label: busy ? 'Menyiapkan…' : 'Nyalakan pengingat',
              icon: Icons.notifications_active_rounded,
              height: 48,
              onPressed: busy ? null : onEnable,
            ),
          ],
        ],
      ),
    );
  }
}
