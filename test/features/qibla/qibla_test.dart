import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:muslimku/features/qibla/domain/qibla.dart';

void main() {
  group('qiblaBearing', () {
    test('matches published directions', () {
      // Kemenag: Jakarta 295°08'. Qibla-finder references: London, New York.
      expect(qiblaBearing(-6.2088, 106.8456), closeTo(295.15, 0.05));
      expect(qiblaBearing(-7.8166, 112.0114), closeTo(294.32, 0.05));
      expect(qiblaBearing(51.5074, -0.1278), closeTo(118.99, 0.05));
      expect(qiblaBearing(40.7128, -74.0060), closeTo(58.48, 0.05));
    });

    test('always returns degrees in [0, 360)', () {
      for (final p in [
        [0.0, 0.0],
        [-33.87, 151.21],
        [21.0, 40.5],
        [64.1, -21.9],
      ]) {
        final b = qiblaBearing(p[0], p[1]);
        expect(b, greaterThanOrEqualTo(0));
        expect(b, lessThan(360));
      }
    });
  });

  group('compassHeading (Android device axes)', () {
    const g = 9.81;
    // Horizontal field 30 µT towards north, 20 µT pointing down.
    double? flat(double mx, double my) =>
        compassHeading(ax: 0, ay: 0, az: g, mx: mx, my: my, mz: -20);

    test('phone lying flat, top edge to each cardinal direction', () {
      expect(flat(0, 30), closeTo(0, 1e-9));
      expect(flat(-30, 0), closeTo(90, 1e-9));
      expect(flat(0, -30), closeTo(180, 1e-9));
      expect(flat(30, 0), closeTo(270, 1e-9));
    });

    test('tilting the phone forward does not change the heading', () {
      const t = 30 * math.pi / 180;
      // Rotate gravity and the field about the x axis by the same pitch.
      List<double> rot(double y, double z) => [
        y * math.cos(t) + z * math.sin(t),
        -y * math.sin(t) + z * math.cos(t),
      ];
      final gv = rot(0, g);
      final bv = rot(30, -20);
      final h = compassHeading(
        ax: 0,
        ay: gv[0],
        az: gv[1],
        mx: 0,
        my: bv[0],
        mz: bv[1],
      );
      expect(h, closeTo(0, 1e-9));
    });

    test('gives up in free fall or without a usable field', () {
      expect(
        compassHeading(ax: 0, ay: 0, az: 0.2, mx: 0, my: 30, mz: -20),
        isNull,
      );
      expect(
        compassHeading(ax: 0, ay: 0, az: g, mx: 0, my: 0, mz: -20),
        isNull,
      );
    });
  });

  group('relativeAngle', () {
    test('signed shortest turn from the heading to the bearing', () {
      expect(relativeAngle(294.3, 290), closeTo(4.3, 1e-9));
      expect(relativeAngle(10, 350), closeTo(20, 1e-9));
      expect(relativeAngle(350, 10), closeTo(-20, 1e-9));
      expect(relativeAngle(90, 270), closeTo(180, 1e-9));
    });
  });

  group('HeadingSmoother', () {
    test('averages on the circle, not across 0°', () {
      final s = HeadingSmoother(factor: 0.5);
      expect(s.add(350), closeTo(350, 1e-9));
      final v = s.add(10);
      expect(v < 1 || v > 359, isTrue, reason: 'got $v');
    });
  });

  group('qiblaInstruction', () {
    test('tells the user which way to turn', () {
      expect(qiblaInstruction(294.32, 290), 'Putar ke kanan 4°');
      expect(qiblaInstruction(294.32, 300), 'Putar ke kiri 6°');
      expect(qiblaInstruction(294.32, 292), 'Sudah menghadap kiblat');
    });
  });
}
