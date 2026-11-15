import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muslimku/core/time/clock_provider.dart';
import 'package:muslimku/features/location/application/location_provider.dart';
import 'package:muslimku/features/prayer/application/prayer_offsets_provider.dart';
import 'package:muslimku/features/prayer/application/prayer_time_provider.dart';
import 'package:muslimku/features/prayer/data/home_widget_gateway.dart';
import 'package:muslimku/features/prayer/data/prayer_schedule_repository.dart';
import 'package:muslimku/features/prayer/domain/prayer_schedule.dart'
    show titleCaseCity;
import 'package:muslimku/features/prayer/domain/widget_payload.dart';

/// Keeps the home-screen widget fed: whenever today's schedule, the city or
/// a correction changes, the next seven saved days go out through
/// [HomeWidgetGateway]. Watched by HomeScreen so it lives with the app.
final homeWidgetSyncProvider = Provider<HomeWidgetSync>((ref) {
  final sync = HomeWidgetSync(ref);
  ref.listen(prayerTimeProvider.select((s) => s.prayerTime), (_, _) {
    sync.refresh();
  });
  ref.listen(prayerOffsetsProvider, (_, _) => sync.refresh());
  ref.listen(locationProvider.select((s) => s.cityId), (_, _) {
    sync.refresh();
  });
  return sync;
});

class HomeWidgetSync {
  HomeWidgetSync(this._ref);

  final Ref _ref;
  int _generation = 0;

  Future<void> refresh() async {
    final gateway = _ref.read(homeWidgetGatewayProvider);
    if (!gateway.supported) return;
    final generation = ++_generation;
    final location = _ref.read(locationProvider);
    final model = _ref.read(prayerTimeProvider).prayerTime;
    final now = _ref.read(nowProvider)();
    final offsets = _ref.read(prayerOffsetsProvider);
    List<dynamic> days;
    try {
      days = [
        for (final d
            in await _ref
                .read(prayerScheduleRepositoryProvider)
                .upcoming(location.cityId, now, days: WidgetPayload.maxDays))
          offsets.apply(d),
      ];
    } catch (_) {
      days = [if (model != null) model.jadwal];
    }
    if (generation != _generation) return;
    if (days.isEmpty) return;
    await gateway.publish(
      WidgetPayload.build(
        city: titleCaseCity(model?.lokasi ?? location.cityName),
        days: days.cast(),
        updatedAt: now,
      ),
    );
  }
}
