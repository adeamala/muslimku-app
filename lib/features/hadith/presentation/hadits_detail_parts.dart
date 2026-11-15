import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muslimku/core/theme/app_colors.dart';
import 'package:muslimku/core/theme/app_text_styles.dart';
import 'package:muslimku/features/reading/application/reading_settings_provider.dart';
import 'package:muslimku/shared/widgets/senja/senja.dart';
import 'package:shimmer/shimmer.dart';

/// [SenjaDetailAppBar] whose text shrinks (down to 80 %) when the title would
/// not fit, so "Bulughul Maram · No. 1597" keeps its number on narrow phones
/// and at large text sizes; the shared bar would cut it with "…".
class HaditsDetailAppBar extends StatelessWidget {
  const HaditsDetailAppBar({
    super.key,
    required this.title,
    required this.subtitle,
    required this.actions,
  });

  final String title;
  final String subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final bar = SenjaDetailAppBar(
      title: title,
      subtitle: subtitle,
      leadingIcon: Icons.chevron_left_rounded,
      actions: actions,
    );
    // Side padding 2×12, back button 40 + 6, gap 6, actions 40 + 6 each.
    final available = media.size.width - 24 - 46 - 6 - actions.length * 46 + 6;
    final painter = TextPainter(
      text: TextSpan(
        text: title,
        style: const TextStyle(
          fontFamily: AppTextStyles.fontFamily,
          fontSize: 16.5,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
      textScaler: media.textScaler,
      maxLines: 1,
    )..layout();
    final width = painter.width;
    painter.dispose();
    if (width <= available || available <= 0) return bar;
    final current = media.textScaler.scale(16.5) / 16.5;
    final fitted = (current * available / width).clamp(0.8, current);
    return MediaQuery(
      data: media.copyWith(textScaler: TextScaler.linear(fitted)),
      child: bar,
    );
  }
}

/// "‹ No. 15   [salin] [bagikan]   No. 17 ›" inside the floating bar.
class HaditsStepBar extends StatelessWidget {
  const HaditsStepBar({
    super.key,
    required this.number,
    required this.total,
    required this.onGo,
    this.onCopy,
    this.onShare,
  });

  final int number;
  final int total;
  final ValueChanged<int> onGo;
  final VoidCallback? onCopy;
  final VoidCallback? onShare;

  @override
  Widget build(BuildContext context) {
    final hasPrev = number > 1;
    final hasNext = number < total;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Semantics(
            hint: 'Hadits sebelumnya',
            child: SenjaStepButton(
              label: hasPrev ? 'No. ${number - 1}' : 'Awal',
              onPressed: hasPrev ? () => onGo(number - 1) : null,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SenjaIconButton(
                icon: Icons.copy_rounded,
                tooltip: 'Salin hadits',
                iconSize: 21,
                color: AppColors.ink,
                onPressed: onCopy,
              ),
              const SizedBox(width: 6),
              SenjaIconButton(
                icon: Icons.ios_share_rounded,
                tooltip: 'Bagikan hadits',
                iconSize: 21,
                color: AppColors.ink,
                onPressed: onShare,
              ),
            ],
          ),
        ),
        Flexible(
          child: Semantics(
            hint: 'Hadits berikutnya',
            child: SenjaStepButton(
              label: hasNext ? 'No. ${number + 1}' : 'Akhir',
              next: true,
              onPressed: hasNext ? () => onGo(number + 1) : null,
            ),
          ),
        ),
      ],
    );
  }
}

/// Grey shapes of the detail page while a hadith loads. Still when the
/// phone asks for fewer animations.
class HaditsDetailSkeleton extends StatelessWidget {
  const HaditsDetailSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    Widget bar(double width, double height, {double radius = 8}) => Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.lilac,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
    final body = Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          bar(124, 22),
          const SizedBox(height: 14),
          bar(240, 26),
          const SizedBox(height: 8),
          bar(110, 14),
          const SizedBox(height: 18),
          bar(double.infinity, 168, radius: 22),
          const SizedBox(height: 22),
          bar(100, 12),
          const SizedBox(height: 12),
          for (var i = 0; i < 5; i++) ...[
            bar(i == 4 ? 180 : double.infinity, 14),
            const SizedBox(height: 11),
          ],
        ],
      ),
    );
    return Semantics(
      label: 'Memuat hadits',
      child: ExcludeSemantics(
        child: MediaQuery.disableAnimationsOf(context)
            ? body
            : Shimmer.fromColors(
                baseColor: AppColors.lilac,
                highlightColor: const Color(0xFFF8F7FF),
                child: body,
              ),
      ),
    );
  }
}

/// "Aa": the Arabic size of all reading pages (`readingSettingsProvider`).
Future<void> showArabicSizeSheet(BuildContext context, {String? sample}) {
  return showSenjaSheet<void>(
    context,
    title: 'Ukuran huruf Arab',
    titleAction: Consumer(
      builder: (context, ref, _) => TextButton(
        onPressed: () => ref
            .read(readingSettingsProvider.notifier)
            .setArabicSize(ReadingSettings.defaultArabicSize),
        style: TextButton.styleFrom(foregroundColor: AppColors.secondary),
        child: const Text(
          'Atur ulang',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
        ),
      ),
    ),
    builder: (_) => _ArabicSizeBody(sample: sample),
  );
}

class _ArabicSizeBody extends ConsumerWidget {
  const _ArabicSizeBody({this.sample});

  final String? sample;

  static const _fallback = 'بِسْمِ اللّٰهِ الرَّحْمٰنِ الرَّحِيْمِ';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final size = ref.watch(readingSettingsProvider.select((s) => s.arabicSize));
    final words = (sample ?? '').split(' ').where((w) => w.isNotEmpty);
    final preview = words.isEmpty ? _fallback : words.take(7).join(' ');
    final muted = TextStyle(
      fontWeight: FontWeight.w800,
      color: AppColors.inkMuted,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.stageBackground,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.lilacLine, width: 1.5),
          ),
          child: ArabicText(
            preview,
            size: size * 0.86,
            align: TextAlign.center,
            maxLines: 2,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Text(
                'Ukuran huruf Arab',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.lilac,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${size.round()}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.secondary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Text('A', style: muted.copyWith(fontSize: 12)),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 6,
                  activeTrackColor: AppColors.secondary,
                  inactiveTrackColor: AppColors.lilac,
                  thumbColor: AppColors.secondary,
                  overlayColor: AppColors.secondary.withValues(alpha: 0.12),
                  inactiveTickMarkColor: Colors.transparent,
                  activeTickMarkColor: Colors.transparent,
                ),
                child: Slider(
                  value: size.clamp(
                    ReadingSettings.minArabicSize,
                    ReadingSettings.maxArabicSize,
                  ),
                  min: ReadingSettings.minArabicSize,
                  max: ReadingSettings.maxArabicSize,
                  divisions: 20,
                  semanticFormatterCallback: (v) => 'Ukuran ${v.round()}',
                  onChanged: ref
                      .read(readingSettingsProvider.notifier)
                      .setArabicSize,
                ),
              ),
            ),
            Text('A', style: muted.copyWith(fontSize: 21)),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Berlaku untuk Al-Qur\'an, hadits, dan doa.',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.inkMuted,
          ),
        ),
      ],
    );
  }
}
