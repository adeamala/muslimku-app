import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muslimku/core/state/mounted_flag.dart';
import 'package:muslimku/features/location/application/location_provider.dart';
import 'package:muslimku/features/location/domain/nearest_city.dart';
import 'package:muslimku/features/prayer/domain/prayer_schedule.dart';
import 'package:muslimku/features/qibla/application/qibla_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// MyQuran cities with coordinates, bundled with the app.
final cityTableProvider = FutureProvider<List<CityPoint>>(
  (ref) async =>
      parseCityTable(await rootBundle.loadString('assets/data/kota.json')),
);

class DeviceCityState {
  const DeviceCityState({this.busy = false, this.deviceCityId});

  final bool busy;

  /// City id last chosen from the phone's location (to show "dari lokasi HP").
  final String? deviceCityId;
}

/// "Pakai lokasi saya": picks the nearest MyQuran city from the phone's
/// approximate position. The position is only used on the phone.
final deviceCityProvider =
    NotifierProvider<DeviceCityNotifier, DeviceCityState>(
      DeviceCityNotifier.new,
    );

class DeviceCityNotifier extends Notifier<DeviceCityState> {
  @override
  DeviceCityState build() {
    _alive = MountedFlag(ref);
    _load();
    return const DeviceCityState();
  }

  late MountedFlag _alive;

  static const key = 'device_city_id';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (_alive.mounted) {
      state = DeviceCityState(deviceCityId: prefs.getString(key));
    }
  }

  /// Returns the message to show to the user.
  Future<String> useDeviceLocation() async {
    if (state.busy) return 'Sedang mencari lokasi…';
    state = DeviceCityState(busy: true, deviceCityId: state.deviceCityId);
    try {
      final location = await ref.read(qiblaLocationSourceProvider).locate();
      switch (location.status) {
        case QiblaLocationStatus.ok:
          final cities = await ref.read(cityTableProvider.future);
          final city = nearestCity(
            location.latitude!,
            location.longitude!,
            cities,
          );
          if (city == null) return 'Kota terdekat tidak ditemukan.';
          await ref
              .read(locationProvider.notifier)
              .selectCity(city.id, city.name);
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(key, city.id);
          if (_alive.mounted) state = DeviceCityState(deviceCityId: city.id);
          return 'Kota diatur ke ${titleCaseCity(city.name)}';
        case QiblaLocationStatus.denied:
          return 'Izin lokasi ditolak.';
        case QiblaLocationStatus.deniedForever:
          return 'Izin lokasi ditolak. Izinkan lewat pengaturan HP.';
        case QiblaLocationStatus.serviceDisabled:
          return 'Lokasi HP sedang mati. Nyalakan lalu coba lagi.';
        case QiblaLocationStatus.unavailable:
          return 'Lokasi belum terbaca. Coba lagi sebentar.';
      }
    } catch (_) {
      return 'Lokasi belum terbaca. Coba lagi sebentar.';
    } finally {
      if (_alive.mounted && state.busy) {
        state = DeviceCityState(deviceCityId: state.deviceCityId);
      }
    }
  }
}
