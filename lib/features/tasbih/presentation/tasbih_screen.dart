import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:muslimku/core/theme/app_colors.dart';
import 'package:muslimku/core/theme/app_text_styles.dart';
import 'package:muslimku/features/tasbih/application/tasbih_provider.dart';
import 'package:muslimku/shared/widgets/diorama/diorama_widgets.dart';

/// Dzikir after salat, 33 times each. Arabic copied from MyQuran texts.
const _dzikir = [
  ('سُبْحَانَ اللهِ', 'Subhanallah'),
  ('اَلْحَمْدُ لِلَّهِ', 'Alhamdulillah'),
  ('اَللّٰهُ اَكْبَرُ', 'Allahu Akbar'),
];

class TasbihScreen extends ConsumerWidget {
  const TasbihScreen({super.key, this.preset});

  /// Shown instead of the dzikir after salat, with its own unsaved counter
  /// (e.g. "Dzikir 33×" of a name from Asmaul Husna).
  final TasbihPreset? preset;

  ProviderListenable<TasbihState> get _state =>
      preset == null ? tasbihProvider : tasbihSessionProvider(preset!);

  ProviderListenable<TasbihCounter> get _notifier => preset == null
      ? tasbihProvider.notifier
      : tasbihSessionProvider(preset!).notifier;

  Future<void> _confirmReset(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ulangi dari nol?'),
        content: const Text('Hitungan tasbih akan kembali ke 0.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Ulangi'),
          ),
        ],
      ),
    );
    if (ok == true) ref.read(_notifier).reset();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(_state);
    final notifier = ref.read(_notifier);
    final dzikir = preset != null
        ? (preset!.arabic, preset!.latin)
        : s.dzikirIndex == null
        ? null
        : _dzikir[s.dzikirIndex!];

    return Scaffold(
      backgroundColor: AppColors.stageBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Tasbih',
          style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.ink),
        ),
        actions: [
          IconButton(
            tooltip: 'Ulangi dari nol',
            icon: Icon(Icons.restart_alt_rounded, color: AppColors.ink),
            onPressed: s.count == 0 ? null : () => _confirmReset(context, ref),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final dial = math.min(constraints.maxWidth - 80, 260.0);
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 24,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      children: [
                        FloatingArt(
                          distance: 4,
                          child: Image.asset(
                            'images/3d/tasbih_large.webp',
                            height: 120,
                            excludeFromSemantics: true,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 72,
                          child: dzikir == null
                              ? Center(
                                  child: Text(
                                    'Ketuk lingkaran untuk menghitung',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: AppColors.inkMuted,
                                    ),
                                  ),
                                )
                              : Column(
                                  children: [
                                    Text(
                                      dzikir.$1,
                                      textDirection: TextDirection.rtl,
                                      style: TextStyle(
                                        fontFamily:
                                            AppTextStyles.arabicFontFamily,
                                        fontSize: 26,
                                        height: 1.6,
                                        color: AppColors.ink,
                                      ),
                                    ),
                                    Text(
                                      dzikir.$2,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.secondary,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _CounterDial(
                      size: dial,
                      state: s,
                      onTap: () {
                        final completed = notifier.increment();
                        if (completed) {
                          HapticFeedback.heavyImpact();
                        } else {
                          HapticFeedback.selectionClick();
                        }
                      },
                    ),
                    const SizedBox(height: 20),
                    Column(
                      children: [
                        Text(
                          s.target == 0
                              ? 'Total ${s.count}'
                              : 'Putaran selesai: ${s.completedRounds}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.inkMuted,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            for (final t in TasbihNotifier.targets)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                ),
                                child: ChoiceChip(
                                  label: Text(t == 0 ? 'Bebas' : '$t×'),
                                  selected: s.target == t,
                                  showCheckmark: false,
                                  selectedColor: AppColors.secondary,
                                  backgroundColor: AppColors.surface,
                                  side: BorderSide(color: AppColors.lilacLine),
                                  labelStyle: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: s.target == t
                                        ? Colors.white
                                        : AppColors.ink,
                                  ),
                                  onSelected: (_) => notifier.setTarget(t),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _CounterDial extends StatelessWidget {
  const _CounterDial({
    required this.size,
    required this.state,
    required this.onTap,
  });

  final double size;
  final TasbihState state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final progress = state.target == 0 ? 0.0 : state.roundCount / state.target;
    final label = state.target == 0 ? 'tanpa target' : 'dari ${state.target}';
    return Semantics(
      button: true,
      label: 'Tambah hitungan. Sekarang ${state.roundCount} $label',
      excludeSemantics: true,
      child: SizedBox(
        width: size + 28,
        height: size + 28,
        child: CustomPaint(
          painter: _RingPainter(progress),
          child: Center(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x332A1C9E),
                    blurRadius: 24,
                    offset: Offset(0, 12),
                  ),
                ],
              ),
              child: Material(
                color: AppColors.primary,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onTap,
                  child: SizedBox(
                    width: size,
                    height: size,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${state.roundCount}',
                          style: TextStyle(
                            fontSize: size * 0.3,
                            height: 1,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -2,
                            color: AppColors.ink,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.inkMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    const stroke = 8.0;
    final r = rect.deflate(stroke / 2);
    canvas.drawArc(
      r,
      0,
      math.pi * 2,
      false,
      Paint()
        ..color = AppColors.lilacLine
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );
    if (progress > 0) {
      canvas.drawArc(
        r,
        -math.pi / 2,
        math.pi * 2 * progress.clamp(0.0, 1.0),
        false,
        Paint()
          ..color = AppColors.secondary
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = stroke,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress;
}
