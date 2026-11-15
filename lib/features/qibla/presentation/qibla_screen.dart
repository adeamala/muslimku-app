import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muslimku/core/theme/app_colors.dart';
import 'package:muslimku/core/theme/app_text_styles.dart';
import 'package:muslimku/features/qibla/application/qibla_provider.dart';
import 'package:muslimku/features/qibla/domain/qibla.dart';
import 'package:muslimku/shared/widgets/diorama/diorama_widgets.dart';

/// Qibla compass. The position comes from the phone's GPS (approximate is
/// enough) and never leaves the device; the heading from the magnetometer.
class QiblaScreen extends ConsumerStatefulWidget {
  const QiblaScreen({super.key});

  @override
  ConsumerState<QiblaScreen> createState() => _QiblaScreenState();
}

class _QiblaScreenState extends ConsumerState<QiblaScreen> {
  QiblaLocation? _location;
  bool _locating = true;
  bool _sensorSilent = false;
  bool _wasAligned = false;
  Timer? _sensorTimer;

  @override
  void initState() {
    super.initState();
    _locate();
  }

  @override
  void dispose() {
    _sensorTimer?.cancel();
    super.dispose();
  }

  Future<void> _locate() async {
    setState(() => _locating = true);
    final location = await ref.read(qiblaLocationSourceProvider).locate();
    if (!mounted) return;
    setState(() {
      _location = location;
      _locating = false;
    });
    if (location.status == QiblaLocationStatus.ok) {
      _sensorTimer?.cancel();
      _sensorTimer = Timer(const Duration(seconds: 4), () {
        if (mounted && !ref.read(headingProvider).hasValue) {
          setState(() => _sensorSilent = true);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final location = _location;
    final bearing = location?.status == QiblaLocationStatus.ok
        ? qiblaBearing(location!.latitude!, location.longitude!)
        : null;

    if (bearing != null) {
      ref.listen<AsyncValue<double>>(headingProvider, (previous, next) {
        final heading = next.valueOrNull;
        if (heading == null) return;
        _sensorTimer?.cancel();
        if (_sensorSilent) setState(() => _sensorSilent = false);
        final aligned = relativeAngle(bearing, heading).abs() <= qiblaTolerance;
        if (aligned && !_wasAligned) HapticFeedback.mediumImpact();
        _wasAligned = aligned;
      });
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: Colors.white,
        systemOverlayStyle: SystemUiOverlayStyle.light.copyWith(
          statusBarColor: Colors.transparent,
        ),
        title: const Text(
          'Arah Kiblat',
          style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white),
        ),
      ),
      body: DuskSky(
        glowAlignment: const Alignment(0, 1.1),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: _locating
                ? const _Message(
                    title: 'Mencari lokasi…',
                    body:
                        'Lokasi hanya dipakai di HP ini untuk menghitung arah kiblat.',
                    busy: true,
                  )
                : bearing == null
                ? _locationProblem(location)
                : _compass(bearing, location!),
          ),
        ),
      ),
    );
  }

  Widget _locationProblem(QiblaLocation? location) {
    final source = ref.read(qiblaLocationSourceProvider);
    switch (location?.status) {
      case QiblaLocationStatus.denied:
        return _Message(
          title: 'Izinkan akses lokasi',
          body:
              'Muslimku butuh perkiraan lokasi untuk menghitung arah kiblat. Lokasi tidak dikirim ke mana pun.',
          action: 'Izinkan',
          onAction: _locate,
        );
      case QiblaLocationStatus.deniedForever:
        return _Message(
          title: 'Akses lokasi ditolak',
          body: 'Buka Pengaturan, pilih Izin > Lokasi, lalu izinkan Muslimku.',
          action: 'Buka pengaturan',
          onAction: source.openAppSettings,
          secondary: 'Coba lagi',
          onSecondary: _locate,
        );
      case QiblaLocationStatus.serviceDisabled:
        return _Message(
          title: 'Lokasi (GPS) belum aktif',
          body: 'Nyalakan lokasi di HP, lalu coba lagi.',
          action: 'Aktifkan lokasi',
          onAction: source.openLocationSettings,
          secondary: 'Coba lagi',
          onSecondary: _locate,
        );
      default:
        return _Message(
          title: 'Lokasi belum didapat',
          body: 'Pastikan lokasi aktif dan sinyal cukup, lalu coba lagi.',
          action: 'Coba lagi',
          onAction: _locate,
        );
    }
  }

  Widget _compass(double bearing, QiblaLocation location) {
    final headingAsync = ref.watch(headingProvider);
    final heading = headingAsync.valueOrNull;
    final noSensor =
        headingAsync.hasError || (_sensorSilent && heading == null);
    final aligned =
        heading != null &&
        relativeAngle(bearing, heading).abs() <= qiblaTolerance;
    final instruction = heading == null
        ? (noSensor ? 'Sensor kompas tidak tersedia' : 'Membaca kompas…')
        : qiblaInstruction(bearing, heading);

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = math.min(constraints.maxWidth, 320.0);
        return SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 8),
              Text(
                'Kiblat ${bearing.round()}° dari utara',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(height: 20),
              Semantics(
                label: 'Kompas kiblat. $instruction',
                excludeSemantics: true,
                child: _Compass(
                  size: size,
                  bearing: bearing,
                  heading: heading ?? 0,
                  aligned: aligned,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                instruction,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: aligned ? AppColors.primary : Colors.white,
                ),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0x330F0846),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.18),
                  ),
                ),
                child: Text(
                  noSensor
                      ? 'HP ini tidak punya sensor kompas. Gunakan kompas biasa: kiblat berada ${bearing.round()}° searah jarum jam dari utara.'
                      : 'Letakkan HP mendatar dan jauhkan dari benda logam atau magnet. Kalau arah melompat-lompat, gerakkan HP membentuk angka 8 untuk kalibrasi.',
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.5,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Lokasi ${location.latitude!.toStringAsFixed(2)}, ${location.longitude!.toStringAsFixed(2)} · hanya dipakai di HP ini',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Compass extends StatelessWidget {
  const _Compass({
    required this.size,
    required this.bearing,
    required this.heading,
    required this.aligned,
  });

  final double size;
  final double bearing;
  final double heading;
  final bool aligned;

  @override
  Widget build(BuildContext context) {
    const rad = math.pi / 180;
    const marker = 54.0;
    return SizedBox(
      width: size,
      height: size + 18,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: 18,
            child: Transform.rotate(
              angle: -heading * rad,
              child: SizedBox(
                width: size,
                height: size,
                child: Stack(
                  children: [
                    CustomPaint(
                      size: Size.square(size),
                      painter: _DialPainter(aligned: aligned),
                    ),
                    // Ka'bah on the ring at the qibla bearing, kept upright.
                    Positioned.fill(
                      child: Transform.rotate(
                        angle: bearing * rad,
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 26),
                            child: Transform.rotate(
                              angle: (heading - bearing) * rad,
                              child: Image.asset(
                                'images/3d/kaaba.webp',
                                width: marker,
                                height: marker,
                                excludeFromSemantics: true,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Fixed pointer: where the top of the phone points.
          Positioned(
            top: 0,
            child: CustomPaint(
              size: const Size(26, 22),
              painter: _PointerPainter(
                aligned ? AppColors.primary : Colors.white,
              ),
            ),
          ),
          Positioned(
            top: 18 + size / 2 - 32,
            child: Column(
              children: [
                Text(
                  '${bearing.round()}°',
                  style: const TextStyle(
                    fontSize: 40,
                    height: 1,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'arah kiblat',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DialPainter extends CustomPainter {
  const _DialPainter({required this.aligned});

  final bool aligned;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    canvas.drawCircle(
      c,
      r,
      Paint()..color = Colors.white.withValues(alpha: 0.08),
    );
    canvas.drawCircle(
      c,
      r - 1,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = aligned
            ? AppColors.primary
            : Colors.white.withValues(alpha: 0.35),
    );
    canvas.drawCircle(c, r * 0.42, Paint()..color = const Color(0x330F0846));
    for (var deg = 0; deg < 360; deg += 5) {
      final major = deg % 30 == 0;
      final a = (deg - 90) * math.pi / 180;
      final dir = Offset(math.cos(a), math.sin(a));
      final outer = c + dir * (r - 6);
      final inner = c + dir * (r - (major ? 18 : 12));
      canvas.drawLine(
        inner,
        outer,
        Paint()
          ..strokeWidth = major ? 2.4 : 1.2
          ..strokeCap = StrokeCap.round
          ..color = Colors.white.withValues(alpha: major ? 0.75 : 0.35),
      );
    }
    const labels = {0: 'U', 90: 'T', 180: 'S', 270: 'B'};
    labels.forEach((deg, text) {
      final a = (deg - 90) * math.pi / 180;
      final p = c + Offset(math.cos(a), math.sin(a)) * (r - 34);
      final tp = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            fontFamily: AppTextStyles.fontFamily,
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: deg == 0 ? AppColors.primary : Colors.white,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, p - Offset(tp.width / 2, tp.height / 2));
    });
  }

  @override
  bool shouldRepaint(_DialPainter old) => old.aligned != aligned;
}

class _PointerPainter extends CustomPainter {
  const _PointerPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width / 2, size.height)
      ..lineTo(0, 0)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_PointerPainter old) => old.color != color;
}

class _Message extends StatelessWidget {
  const _Message({
    required this.title,
    required this.body,
    this.action,
    this.onAction,
    this.secondary,
    this.onSecondary,
    this.busy = false,
  });

  final String title;
  final String body;
  final String? action;
  final VoidCallback? onAction;
  final String? secondary;
  final VoidCallback? onSecondary;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'images/3d/icon_kiblat.webp',
            height: 120,
            excludeFromSemantics: true,
          ),
          const SizedBox(height: 20),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            body,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14.5,
              height: 1.5,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 22),
          if (busy)
            const CircularProgressIndicator(color: AppColors.primary)
          else if (action != null)
            FilledButton(
              onPressed: onAction,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.ink,
                padding: const EdgeInsets.symmetric(
                  horizontal: 26,
                  vertical: 14,
                ),
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              child: Text(action!),
            ),
          if (secondary != null) ...[
            const SizedBox(height: 6),
            TextButton(
              onPressed: onSecondary,
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              child: Text(secondary!),
            ),
          ],
        ],
      ),
    );
  }
}
