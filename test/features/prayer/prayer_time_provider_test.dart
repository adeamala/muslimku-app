import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muslimku/core/network/api_service.dart';
import 'package:muslimku/features/prayer/application/prayer_time_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Fails the first request (e.g. a weak signal), succeeds afterwards.
class _FlakyPrayerApi extends ApiService {
  int calls = 0;

  @override
  Future<Map<String, dynamic>?> getPrayerTimes(
    String cityId,
    String date,
  ) async {
    calls++;
    if (calls == 1) {
      throw Exception('offline');
    }
    return {
      'id': cityId,
      'lokasi': 'KOTA KEDIRI',
      'daerah': 'JAWA TIMUR',
      'jadwal': {
        'tanggal': 'Sabtu, 25/10/2026',
        'imsak': '03:55',
        'subuh': '04:05',
        'terbit': '05:17',
        'dhuha': '05:45',
        'dzuhur': '11:24',
        'ashar': '14:36',
        'maghrib': '17:30',
        'isya': '18:39',
        'date': '2026-10-25',
      },
    };
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // The provider reads the saved prayer-time corrections.
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('a successful reload clears the error left by a failed load', () async {
    final api = _FlakyPrayerApi();
    final container = ProviderContainer(
      overrides: [apiServiceProvider.overrideWithValue(api)],
    );
    addTearDown(container.dispose);
    final notifier = container.read(prayerTimeProvider.notifier);

    await notifier.loadPrayerTimes(cityId: '1632');
    expect(container.read(prayerTimeProvider).error, isNotNull);

    await notifier.loadPrayerTimes(cityId: '1632');
    final state = container.read(prayerTimeProvider);
    expect(api.calls, 2);
    expect(state.prayerTime?.lokasi, 'KOTA KEDIRI');
    expect(state.error, isNull);
  });
}
