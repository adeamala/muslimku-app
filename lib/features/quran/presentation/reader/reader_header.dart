import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'package:muslimku/core/theme/app_colors.dart';
import 'package:muslimku/core/theme/app_text_styles.dart';
import 'package:muslimku/core/utils/arabic_text.dart';
import 'package:muslimku/features/quran/domain/quran_models.dart';
import 'package:muslimku/shared/widgets/senja/senja.dart';

/// Faint lilac text on the night page (design `.nm`).
const _nightMeta = Color(0xFFA9A3D6);

/// Purple surah card at the top of the reader in the light themes (q3).
class ReaderBanner extends StatelessWidget {
  const ReaderBanner({
    super.key,
    required this.surah,
    required this.playing,
    required this.onPlay,
    required this.onTafsir,
    this.onMurottal,
  });

  final Surah surah;

  /// The murottal of this surah is playing (the pill pauses it).
  final bool playing;
  final VoidCallback onPlay;
  final VoidCallback onTafsir;

  /// Opens "Murottal offline" (download for playback without internet).
  final VoidCallback? onMurottal;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 150),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment(-0.64, -0.77),
          end: Alignment(0.64, 0.77),
          colors: [AppColors.duskHigh, AppColors.duskMid, AppColors.duskLow],
          stops: [0, 0.58, 1],
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: OctagramPatternPainter(
                  color: Colors.white.withValues(alpha: 0.12),
                ),
              ),
            ),
            Positioned(
              right: 20,
              top: 0,
              bottom: 0,
              child: Center(child: _ArabicSeal(surah.arabicName)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 18, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 122),
                    child: Text(
                      surah.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 24,
                        height: 1.26,
                        letterSpacing: -0.3,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Padding(
                    padding: const EdgeInsets.only(right: 122),
                    child: Text(
                      '${surah.meaning} · ${surah.revelation} · '
                      '${surah.verseCount} ayat',
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.26,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.78),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      SenjaPill(
                        label: playing ? 'Jeda murottal' : 'Putar murottal',
                        icon: playing
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        onTap: onPlay,
                      ),
                      SenjaPill(
                        label: 'Tafsir',
                        icon: Icons.menu_book_outlined,
                        lime: false,
                        onTap: onTafsir,
                      ),
                      if (onMurottal != null)
                        SenjaPill(
                          label: 'Murottal offline',
                          icon: Icons.download_rounded,
                          lime: false,
                          onTap: onMurottal!,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Round outline badge with the Arabic surah name (design `.bigar`).
class _ArabicSeal extends StatelessWidget {
  const _ArabicSeal(this.name);

  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 104,
      height: 104,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.35),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.06),
            spreadRadius: 7,
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          name,
          textDirection: TextDirection.rtl,
          textScaler: TextScaler.noScaling,
          style: const TextStyle(
            fontFamily: AppTextStyles.arabicFontFamily,
            fontSize: 46,
            height: 1.25,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

/// The bismillah line above the first ayah.
class ReaderBismillah extends StatelessWidget {
  const ReaderBismillah({
    super.key,
    required this.color,
    this.size = 25,
    this.top = 16,
  });

  final Color color;
  final double size;
  final double top;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, top, 20, 2),
      child: ArabicText(
        bismillah,
        size: size,
        color: color,
        align: TextAlign.center,
        height: 1.8,
      ),
    );
  }
}

/// "Mihrab Emas" header of the night theme (q5): a gold arch behind the
/// Arabic surah name, two lanterns and a soft glow. Drawn under the
/// transparent app bar, so [topInset] is the status bar height.
class NightHeader extends StatelessWidget {
  const NightHeader({
    super.key,
    required this.surah,
    required this.topInset,
    this.autoNight = false,
  });

  final Surah surah;
  final double topInset;

  /// Shows "Mode malam otomatis · setelah Maghrib".
  final bool autoNight;

  @override
  Widget build(BuildContext context) {
    final t = topInset;
    return Stack(
      clipBehavior: Clip.none,
      fit: StackFit.passthrough,
      children: [
        Positioned(
          left: 0,
          right: 0,
          top: t + 106,
          height: 300,
          child: IgnorePointer(
            child: Transform.scale(
              scaleX: 1.4,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      AppColors.gold.withValues(alpha: 0.18),
                      AppColors.gold.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: t + 48,
          child: Center(
            child: ShaderMask(
              blendMode: BlendMode.dstIn,
              shaderCallback: (rect) => const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black, Colors.black, Colors.transparent],
                stops: [0, 0.52, 0.8],
              ).createShader(rect),
              child: Opacity(
                opacity: 0.95,
                child: Image.asset(
                  'images/3d/night_arch.webp',
                  width: 226,
                  excludeFromSemantics: true,
                ),
              ),
            ),
          ),
        ),
        Positioned(left: 30, top: t + 14, child: const _Lantern()),
        Positioned(right: 30, top: t + 14, child: const _Lantern()),
        Padding(
          padding: EdgeInsets.only(top: t + 142),
          child: Column(
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 176),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    surah.arabicName,
                    textDirection: TextDirection.rtl,
                    textScaler: TextScaler.noScaling,
                    style: TextStyle(
                      fontFamily: AppTextStyles.arabicFontFamily,
                      fontSize: 50,
                      height: 1.5,
                      color: AppColors.gold,
                      shadows: [
                        Shadow(
                          color: AppColors.gold.withValues(alpha: 0.35),
                          blurRadius: 18,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${surah.name} · ${surah.meaning}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.nightCream,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${surah.revelation} · ${surah.verseCount} ayat',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: _nightMeta,
                ),
              ),
              if (autoNight) ...[
                const SizedBox(height: 41),
                const _AutoNightChip(),
                const SizedBox(height: 12),
              ] else
                // Keeps the bismillah below the fading end of the arch.
                const SizedBox(height: 64),
            ],
          ),
        ),
      ],
    );
  }
}

class _Lantern extends StatelessWidget {
  const _Lantern();

  static const _asset = 'images/3d/night_lantern.webp';

  @override
  Widget build(BuildContext context) {
    // A blurred gold copy behind the lantern works like CSS drop-shadow.
    return SizedBox(
      width: 44,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: ImageFiltered(
              imageFilter: ui.ImageFilter.blur(sigmaX: 9, sigmaY: 9),
              child: Image.asset(
                _asset,
                width: 44,
                color: AppColors.gold.withValues(alpha: 0.5),
                colorBlendMode: BlendMode.srcIn,
                excludeFromSemantics: true,
              ),
            ),
          ),
          Image.asset(_asset, width: 44, excludeFromSemantics: true),
        ],
      ),
    );
  }
}

class _AutoNightChip extends StatelessWidget {
  const _AutoNightChip();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 13),
          decoration: BoxDecoration(
            color: AppColors.duskNight.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: AppColors.gold.withValues(alpha: 0.5),
              width: 1.5,
            ),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.dark_mode_outlined, size: 15, color: AppColors.gold),
              SizedBox(width: 7),
              Text(
                'Mode malam otomatis · setelah Maghrib',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.gold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
