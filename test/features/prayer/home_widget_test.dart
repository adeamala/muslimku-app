import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:muslimku/app/shell/home_screen.dart';
import 'package:muslimku/features/prayer/application/prayer_offsets_provider.dart';
import 'package:muslimku/features/prayer/data/home_widget_gateway.dart';
import 'package:muslimku/features/prayer/domain/adzan_plan.dart'
    show AdzanPrayer;
import 'package:muslimku/features/prayer/domain/prayer_offsets.dart';
import 'package:muslimku/features/prayer/domain/prayer_time_model.dart';
import 'package:muslimku/features/prayer/domain/widget_payload.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_home_api.dart';
import '../../support/pump_home.dart';

class FakeHomeWidgetGateway implements HomeWidgetGateway {
  final published = <Map<String, String>>[];

  @override
  bool get supported => true;

  @override
  Future<void> publish(Map<String, String> data) async => published.add(data);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => initializeDateFormatting('id_ID', null));
  setUp(() => SharedPreferences.setMockInitialValues({}));

  PrayerSchedule day(String date) => PrayerSchedule.fromJson({
    ...FakeHomeApi.jadwal.jadwal.toJson(),
    'date': date,
  });

  test('payload: city, one row per day, keys the widget reads', () {
    final payload = WidgetPayload.build(
      city: 'Kota Kediri',
      days: [day('2026-10-25'), day('2026-10-26')],
      updatedAt: DateTime(2026, 10, 25, 18, 2),
    );
    expect(payload[WidgetPayload.cityKey], 'Kota Kediri');
    expect(payload[WidgetPayload.updatedKey], '2026-10-25T18:02');
    final days = jsonDecode(payload[WidgetPayload.daysKey]!) as List;
    expect(days, hasLength(2));
    expect(days.first, {
      'date': '2026-10-25',
      'imsak': '03:39',
      'subuh': '03:49',
      'dzuhur': '11:20',
      'ashar': '14:29',
      'maghrib': '17:29',
      'isya': '18:40',
    });
    expect(WidgetPayload.keys, {
      WidgetPayload.cityKey,
      WidgetPayload.daysKey,
      WidgetPayload.updatedKey,
    });
  });

  test('payload: at most seven days, oldest first, nothing without a date', () {
    final payload = WidgetPayload.build(
      city: 'Kota Kediri',
      days: [for (var d = 31; d >= 20; d--) day('2026-10-$d'), day('')],
      updatedAt: DateTime(2026, 10, 25),
    );
    final days = jsonDecode(payload[WidgetPayload.daysKey]!) as List<dynamic>;
    expect(days.map((d) => (d as Map<String, dynamic>)['date']).toList(), [
      for (var d = 20; d <= 26; d++) '2026-10-$d',
    ]);
  });

  testWidgets('Beranda publishes the schedule, again after a correction', (
    tester,
  ) async {
    final gateway = FakeHomeWidgetGateway();
    await pumpHome(
      tester,
      overrides: [homeWidgetGatewayProvider.overrideWithValue(gateway)],
    );
    await tester.pump(const Duration(seconds: 1));
    expect(gateway.published, isNotEmpty);
    final first = gateway.published.last;
    expect(first[WidgetPayload.cityKey], 'Kota Kediri');
    final days = (jsonDecode(first[WidgetPayload.daysKey]!) as List<dynamic>)
        .cast<Map<String, dynamic>>();
    expect(days.first['date'], '2026-10-25');
    expect(days.first['subuh'], '03:49');

    final container = ProviderScope.containerOf(
      tester.element(find.byType(HomeScreen)),
    );
    await container
        .read(prayerOffsetsProvider.notifier)
        .set(AdzanPrayer.subuh, 2);
    await tester.pump(const Duration(seconds: 1));
    final again =
        (jsonDecode(gateway.published.last[WidgetPayload.daysKey]!)
                as List<dynamic>)
            .cast<Map<String, dynamic>>();
    expect(again.first['subuh'], '03:51');
    expect(again.first['imsak'], '03:41');
    expect(PrayerOffsets.none.isZero, isTrue);
  });
}
