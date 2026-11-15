import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muslimku/core/theme/app_theme.dart';
import 'package:muslimku/features/qibla/application/qibla_provider.dart';
import 'package:muslimku/features/qibla/presentation/qibla_screen.dart';

class _FakeLocation implements QiblaLocationSource {
  _FakeLocation(this.results);

  final List<QiblaLocation> results;
  int calls = 0;
  int settingsOpened = 0;

  @override
  Future<QiblaLocation> locate({bool request = true}) async {
    final r = results[calls.clamp(0, results.length - 1)];
    calls++;
    return r;
  }

  @override
  Future<void> openAppSettings() async => settingsOpened++;

  @override
  Future<void> openLocationSettings() async => settingsOpened++;
}

class _FakeHeading implements HeadingSource {
  _FakeHeading(this.stream);

  final Stream<double> stream;

  @override
  Stream<double> headings() => stream;
}

const _kediri = QiblaLocation(
  QiblaLocationStatus.ok,
  latitude: -7.8166,
  longitude: 112.0114,
);

Future<void> _pump(
  WidgetTester tester,
  QiblaLocationSource location,
  Stream<double> headings,
) async {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        qiblaLocationSourceProvider.overrideWithValue(location),
        headingSourceProvider.overrideWithValue(_FakeHeading(headings)),
      ],
      child: MaterialApp(theme: AppTheme.lightTheme, home: const QiblaScreen()),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  testWidgets('shows the bearing and which way to turn', (tester) async {
    await _pump(tester, _FakeLocation([_kediri]), Stream.value(290.0));
    expect(find.text('Kiblat 294° dari utara'), findsOneWidget);
    expect(find.text('294°'), findsOneWidget);
    expect(find.text('Putar ke kanan 4°'), findsOneWidget);
  });

  testWidgets('confirms when the phone faces the qibla', (tester) async {
    await _pump(tester, _FakeLocation([_kediri]), Stream.value(293.0));
    expect(find.text('Sudah menghadap kiblat'), findsOneWidget);
  });

  testWidgets('without a compass sensor it explains the bearing', (
    tester,
  ) async {
    await _pump(
      tester,
      _FakeLocation([_kediri]),
      Stream<double>.error(Exception('NO_SENSOR')),
    );
    expect(find.text('Sensor kompas tidak tersedia'), findsOneWidget);
    expect(find.textContaining('Gunakan kompas biasa'), findsOneWidget);
  });

  testWidgets('a silent sensor is reported after a few seconds', (
    tester,
  ) async {
    final controller = StreamController<double>();
    addTearDown(controller.close);
    await _pump(tester, _FakeLocation([_kediri]), controller.stream);
    expect(find.text('Membaca kompas…'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    expect(find.text('Sensor kompas tidak tersedia'), findsOneWidget);
  });

  testWidgets('asks for permission and retries when allowed', (tester) async {
    final location = _FakeLocation([
      const QiblaLocation(QiblaLocationStatus.denied),
      _kediri,
    ]);
    await _pump(tester, location, Stream.value(290.0));
    expect(find.text('Izinkan akses lokasi'), findsOneWidget);

    await tester.tap(find.text('Izinkan'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(location.calls, 2);
    expect(find.text('Putar ke kanan 4°'), findsOneWidget);
  });

  testWidgets('permanently denied sends the user to the settings', (
    tester,
  ) async {
    final location = _FakeLocation([
      const QiblaLocation(QiblaLocationStatus.deniedForever),
    ]);
    await _pump(tester, location, Stream.value(290.0));
    await tester.tap(find.text('Buka pengaturan'));
    await tester.pump();
    expect(location.settingsOpened, 1);
  });
}
