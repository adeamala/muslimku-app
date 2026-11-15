import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import 'package:muslimku/core/theme/app_colors.dart';
import 'package:muslimku/core/theme/app_text_styles.dart';
import 'package:muslimku/features/quran/application/quran_audio_provider.dart';
import 'package:muslimku/features/quran/presentation/reader/reciter_sheet.dart';

/// Height of [MurottalBar] including its bottom margin (without the safe area).
const murottalBarExtent = 74.0 + 14.0;

/// Dark mini player pinned to the bottom of the reader (design `.player`).
/// Swipe it down to stop the murottal.
class MurottalBar extends StatelessWidget {
  const MurottalBar({
    super.key,
    required this.state,
    required this.progress,
    required this.onPrevious,
    required this.onToggle,
    required this.onNext,
    required this.onStop,
    this.night = false,
  });

  final MurottalState state;
  final ValueListenable<MurottalProgress> progress;
  final VoidCallback onPrevious;
  final VoidCallback onToggle;
  final VoidCallback onNext;
  final VoidCallback onStop;

  /// Thin gold outline on the night page.
  final bool night;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(12, 0, 12, 14 + bottom),
      child: Dismissible(
        key: const ValueKey('murottal-bar'),
        direction: DismissDirection.down,
        onDismissed: (_) => onStop(),
        child: Semantics(
          customSemanticsActions: {
            const CustomSemanticsAction(label: 'Hentikan murottal'): onStop,
          },
          child: Container(
            height: 74,
            decoration: BoxDecoration(
              color: AppColors.ink,
              borderRadius: BorderRadius.circular(24),
              border: night
                  ? Border.all(color: AppColors.gold.withValues(alpha: 0.28))
                  : null,
              boxShadow: [
                BoxShadow(
                  color: AppColors.ink.withValues(alpha: 0.35),
                  blurRadius: 30,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Material(
                    type: MaterialType.transparency,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 12, right: 4),
                      child: Row(
                        children: [
                          _Art(state.arabicName),
                          const SizedBox(width: 12),
                          Expanded(child: _Title(state)),
                          const SizedBox(width: 4),
                          _RoundButton(
                            icon: Icons.skip_previous_rounded,
                            tooltip: 'Ayat sebelumnya',
                            onPressed: onPrevious,
                          ),
                          const SizedBox(width: 2),
                          _PlayPause(state: state, onPressed: onToggle),
                          const SizedBox(width: 2),
                          _RoundButton(
                            icon: Icons.skip_next_rounded,
                            tooltip: 'Ayat berikutnya',
                            onPressed: onNext,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 0,
                    child: ValueListenableBuilder<MurottalProgress>(
                      valueListenable: progress,
                      builder: (context, value, _) => Align(
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: value.fraction,
                          child: Container(height: 3, color: AppColors.primary),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Art extends StatelessWidget {
  const _Art(this.arabicName);

  final String arabicName;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.duskMid, AppColors.duskHigh],
        ),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          arabicName,
          textDirection: TextDirection.rtl,
          textScaler: TextScaler.noScaling,
          style: const TextStyle(
            fontFamily: AppTextStyles.arabicFontFamily,
            fontSize: 24,
            height: 1.3,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }
}

class _Title extends StatelessWidget {
  const _Title(this.state);

  final MurottalState state;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${state.surahName} · Ayat ${state.ayah}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 2),
        // The qari; tap to pick another (applies from the next ayah).
        Semantics(
          button: true,
          label: 'Qari ${state.reciter}, ganti',
          child: InkWell(
            onTap: () => showReciterSheet(context),
            borderRadius: BorderRadius.circular(6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: ExcludeSemantics(
                    child: Text(
                      state.reciter,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.62),
                      ),
                    ),
                  ),
                ),
                Icon(
                  Icons.expand_more_rounded,
                  size: 14,
                  color: Colors.white.withValues(alpha: 0.62),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: SizedBox.square(
          dimension: 40,
          child: Icon(icon, size: 26, color: Colors.white),
        ),
      ),
    );
  }
}

class _PlayPause extends StatelessWidget {
  const _PlayPause({required this.state, required this.onPressed});

  final MurottalState state;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: state.playing ? 'Jeda murottal' : 'Putar murottal',
      child: Material(
        color: AppColors.primary,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox.square(
            dimension: 46,
            child: state.loading
                ? Padding(
                    padding: const EdgeInsets.all(14),
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: AppColors.ink,
                    ),
                  )
                : Icon(
                    state.playing
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    size: 24,
                    color: AppColors.ink,
                  ),
          ),
        ),
      ),
    );
  }
}
