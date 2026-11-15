import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:muslimku/features/qibla/domain/qibla.dart';
import 'package:sensors_plus/sensors_plus.dart';

enum QiblaLocationStatus {
  ok,
  denied,
  deniedForever,
  serviceDisabled,
  unavailable,
}

class QiblaLocation {
  const QiblaLocation(this.status, {this.latitude, this.longitude});

  final QiblaLocationStatus status;
  final double? latitude;
  final double? longitude;
}

/// Where the phone is. The position stays on the device: it is only used to
/// compute the qibla bearing.
abstract class QiblaLocationSource {
  Future<QiblaLocation> locate({bool request = true});
  Future<void> openAppSettings();
  Future<void> openLocationSettings();
}

class GeolocatorQiblaLocationSource implements QiblaLocationSource {
  const GeolocatorQiblaLocationSource();

  @override
  Future<QiblaLocation> locate({bool request = true}) async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const QiblaLocation(QiblaLocationStatus.serviceDisabled);
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied && request) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        return const QiblaLocation(QiblaLocationStatus.deniedForever);
      }
      if (permission == LocationPermission.denied) {
        return const QiblaLocation(QiblaLocationStatus.denied);
      }
      Position? position;
      try {
        position = await Geolocator.getLastKnownPosition();
      } catch (_) {
        position = null; // not supported everywhere (web)
      }
      // A city-level fix is plenty for the qibla, so ask for low accuracy.
      position ??= await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
        timeLimit: const Duration(seconds: 20),
      );
      return QiblaLocation(
        QiblaLocationStatus.ok,
        latitude: position.latitude,
        longitude: position.longitude,
      );
    } catch (_) {
      return const QiblaLocation(QiblaLocationStatus.unavailable);
    }
  }

  @override
  Future<void> openAppSettings() => Geolocator.openAppSettings();

  @override
  Future<void> openLocationSettings() => Geolocator.openLocationSettings();
}

/// Compass heading in degrees from magnetic north.
abstract class HeadingSource {
  Stream<double> headings();
}

class SensorHeadingSource implements HeadingSource {
  const SensorHeadingSource();

  @override
  Stream<double> headings() {
    late final StreamController<double> controller;
    StreamSubscription<AccelerometerEvent>? accSub;
    StreamSubscription<MagnetometerEvent>? magSub;
    AccelerometerEvent? gravity;
    final smoother = HeadingSmoother(factor: 0.15);
    controller = StreamController<double>(
      onListen: () {
        accSub = accelerometerEventStream(
          samplingPeriod: SensorInterval.uiInterval,
        ).listen((e) => gravity = e, onError: controller.addError);
        magSub =
            magnetometerEventStream(
              samplingPeriod: SensorInterval.uiInterval,
            ).listen((m) {
              final a = gravity;
              if (a == null) return;
              final h = compassHeading(
                ax: a.x,
                ay: a.y,
                az: a.z,
                mx: m.x,
                my: m.y,
                mz: m.z,
              );
              if (h != null) controller.add(smoother.add(h));
            }, onError: controller.addError);
      },
      onCancel: () async {
        await accSub?.cancel();
        await magSub?.cancel();
      },
    );
    return controller.stream;
  }
}

final qiblaLocationSourceProvider = Provider<QiblaLocationSource>(
  (ref) => const GeolocatorQiblaLocationSource(),
);

final headingSourceProvider = Provider<HeadingSource>(
  (ref) => const SensorHeadingSource(),
);

final headingProvider = StreamProvider.autoDispose<double>(
  (ref) => ref.watch(headingSourceProvider).headings(),
);
