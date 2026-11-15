/// The city used until the user picks one: Kota Kediri, MyQuran id 1632.
///
/// Nothing else in `lib/` may spell this out (guarded by
/// `test/core/default_city_test.dart`); read `LocationState.cityId` /
/// `cityName`, or these constants where no state is at hand.
abstract final class DefaultCity {
  static const id = '1632';

  /// As MyQuran spells it (upper case), like a saved `selectedCityName`.
  static const apiName = 'KOTA KEDIRI';

  /// For display.
  static const name = 'Kota Kediri';
}
