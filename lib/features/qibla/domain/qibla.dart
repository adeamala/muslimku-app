import 'dart:math' as math;

/// Ka'bah, Masjidil Haram.
const double kaabaLatitude = 21.422487;
const double kaabaLongitude = 39.826206;

/// Initial great-circle bearing from the given point to the Ka'bah, in degrees
/// clockwise from true north, in [0, 360).
double qiblaBearing(double latitude, double longitude) {
  final phi1 = _rad(latitude);
  final phi2 = _rad(kaabaLatitude);
  final dLambda = _rad(kaabaLongitude - longitude);
  final y = math.sin(dLambda) * math.cos(phi2);
  final x =
      math.cos(phi1) * math.sin(phi2) -
      math.sin(phi1) * math.cos(phi2) * math.cos(dLambda);
  return _normalize(_deg(math.atan2(y, x)));
}

/// Direction the top edge of the phone points to, in degrees clockwise from
/// magnetic north, from an accelerometer reading (gravity) and a magnetometer
/// reading, both in Android device axes. This is the same computation as
/// Android's `SensorManager.getRotationMatrix` + `getOrientation`.
///
/// Returns null in free fall or when the field is parallel to gravity.
double? compassHeading({
  required double ax,
  required double ay,
  required double az,
  required double mx,
  required double my,
  required double mz,
}) {
  final normA = math.sqrt(ax * ax + ay * ay + az * az);
  if (normA < 0.98) return null; // under 0.1 g: free fall
  // H = E x A points east.
  var hx = my * az - mz * ay;
  var hy = mz * ax - mx * az;
  var hz = mx * ay - my * ax;
  final normH = math.sqrt(hx * hx + hy * hy + hz * hz);
  if (normH < 0.1) return null;
  hx /= normH;
  hy /= normH;
  hz /= normH;
  final nx = ax / normA;
  final nz = az / normA;
  // M = A x H points north; only its y component is needed.
  final mY = nz * hx - nx * hz;
  return _normalize(_deg(math.atan2(hy, mY)));
}

/// Signed shortest turn from [heading] to [bearing], in (-180, 180].
/// Positive means turn right (clockwise).
double relativeAngle(double bearing, double heading) {
  final d = (bearing - heading) % 360;
  return d > 180 ? d - 360 : d;
}

/// Degrees within which the phone counts as facing the qibla.
const double qiblaTolerance = 3;

String qiblaInstruction(double bearing, double heading) {
  final d = relativeAngle(bearing, heading);
  if (d.abs() <= qiblaTolerance) return 'Sudah menghadap kiblat';
  final turn = d.abs().round();
  return d > 0 ? 'Putar ke kanan $turn°' : 'Putar ke kiri $turn°';
}

/// Exponential smoothing of an angle on the unit circle, so readings around
/// 359°/0° average correctly.
class HeadingSmoother {
  HeadingSmoother({this.factor = 0.2});

  /// Weight of the newest reading (0..1).
  final double factor;
  double? _sin;
  double? _cos;

  double add(double degrees) {
    final r = _rad(degrees);
    if (_sin == null || _cos == null) {
      _sin = math.sin(r);
      _cos = math.cos(r);
    } else {
      _sin = _sin! + factor * (math.sin(r) - _sin!);
      _cos = _cos! + factor * (math.cos(r) - _cos!);
    }
    return _normalize(_deg(math.atan2(_sin!, _cos!)));
  }
}

double _rad(double d) => d * math.pi / 180;
double _deg(double r) => r * 180 / math.pi;
double _normalize(double d) {
  final n = d % 360;
  return n < 0 ? n + 360 : n;
}
