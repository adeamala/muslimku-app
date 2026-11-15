import 'dart:convert';
import 'dart:math' as math;

/// A MyQuran prayer-time city with its coordinates (from assets/data/kota.json).
class CityPoint {
  const CityPoint({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
  });

  final String id;

  /// MyQuran name, e.g. "KOTA KEDIRI".
  final String name;
  final double lat;
  final double lng;
}

List<CityPoint> parseCityTable(String json) => [
  for (final row
      in (jsonDecode(json) as List<dynamic>).cast<Map<String, dynamic>>())
    CityPoint(
      id: '${row['id']}',
      name: '${row['n']}',
      lat: (row['lat'] as num).toDouble(),
      lng: (row['lng'] as num).toDouble(),
    ),
];

/// Great-circle distance in kilometres.
double distanceKm(double lat1, double lng1, double lat2, double lng2) {
  const earthKm = 6371.0;
  double rad(double d) => d * math.pi / 180;
  final dLat = rad(lat2 - lat1);
  final dLng = rad(lng2 - lng1);
  final a =
      math.pow(math.sin(dLat / 2), 2) +
      math.cos(rad(lat1)) *
          math.cos(rad(lat2)) *
          math.pow(math.sin(dLng / 2), 2);
  return 2 * earthKm * math.asin(math.min(1, math.sqrt(a)));
}

/// The city closest to the position, computed on the phone.
CityPoint? nearestCity(double lat, double lng, List<CityPoint> cities) {
  CityPoint? best;
  var bestKm = double.infinity;
  for (final city in cities) {
    final km = distanceKm(lat, lng, city.lat, city.lng);
    if (km < bestKm) {
      bestKm = km;
      best = city;
    }
  }
  return best;
}
