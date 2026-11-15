import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:muslimku/features/location/application/location_provider.dart';
import 'package:muslimku/features/location/domain/default_city.dart';

void main() {
  test('DefaultCity is Kota Kediri, id 1632, in both spellings', () {
    expect(DefaultCity.id, '1632');
    expect(DefaultCity.apiName, 'KOTA KEDIRI');
    expect(DefaultCity.name, 'Kota Kediri');
  });

  test('LocationState falls back to DefaultCity until a city is chosen', () {
    final none = LocationState();
    expect(none.activeCityId, isNull, reason: 'nothing chosen yet');
    expect(none.cityId, DefaultCity.id);
    expect(none.cityName, DefaultCity.apiName);

    final chosen = LocationState(
      selectedCityId: '1301',
      selectedCityName: 'KOTA JAKARTA',
    );
    expect(chosen.cityId, '1301');
    expect(chosen.cityName, 'KOTA JAKARTA');
  });

  test('no other file in lib/ spells out the default city', () {
    // Doc comments may use Kediri as an example; code may not.
    final literal = RegExp(r'1632|KEDIRI|Kediri');
    final comment = RegExp(r'^\s*///?');
    final offenders = <String>[];
    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      final isSource = file.path.endsWith(
        'features/location/domain/default_city.dart',
      );
      if (isSource) continue;
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (comment.hasMatch(line)) continue;
        if (literal.hasMatch(line)) offenders.add('${file.path}:${i + 1}');
      }
    }
    expect(
      offenders,
      isEmpty,
      reason: 'use DefaultCity / LocationState.cityId',
    );
  });
}
