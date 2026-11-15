import 'package:flutter/material.dart';

import 'package:muslimku/core/theme/app_colors.dart';
import 'package:muslimku/features/prayer/domain/prayer_schedule.dart';

/// Six times of the day on one line: passed (filled), next (lime) and
/// upcoming (hollow).
class PrayerTimeline extends StatelessWidget {
  const PrayerTimeline({
    super.key,
    required this.entries,
    required this.states,
  });

  final List<TimelineEntry> entries;
  final List<TimelineState> states;

  @override
  Widget build(BuildContext context) {
    final nextIndex = states.indexOf(TimelineState.next);
    final lastPassed = states.lastIndexOf(TimelineState.passed);
    final fillTo = nextIndex >= 0 ? nextIndex : lastPassed;

    return LayoutBuilder(
      builder: (context, constraints) {
        final columnWidth = constraints.maxWidth / entries.length;
        final lineWidth = columnWidth * (entries.length - 1);
        final filled = fillTo <= 0 ? 0.0 : columnWidth * fillTo;
        return Stack(
          children: [
            Positioned(
              left: columnWidth / 2,
              top: 9.5,
              width: lineWidth,
              height: 3,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.lilacLine,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            Positioned(
              left: columnWidth / 2,
              top: 9.5,
              width: filled,
              height: 3,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.secondary,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            Row(
              children: [
                for (var i = 0; i < entries.length; i++)
                  Expanded(child: _TimelineItem(entries[i], states[i])),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _TimelineItem extends StatelessWidget {
  const _TimelineItem(this.entry, this.state);

  final TimelineEntry entry;
  final TimelineState state;

  @override
  Widget build(BuildContext context) {
    final isNext = state == TimelineState.next;
    final status = switch (state) {
      TimelineState.passed => 'sudah lewat',
      TimelineState.next => 'berikutnya',
      TimelineState.upcoming => 'nanti',
    };
    return Semantics(
      label: '${entry.label} ${entry.time}, $status',
      excludeSemantics: true,
      child: Column(
        children: [
          SizedBox(height: 22, child: Center(child: _Dot(state))),
          SizedBox(height: isNext ? 6 : 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              entry.label,
              maxLines: 1,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: isNext ? AppColors.ink : AppColors.inkMuted,
              ),
            ),
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              entry.time,
              maxLines: 1,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
                fontFeatures: [const FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot(this.state);

  final TimelineState state;

  @override
  Widget build(BuildContext context) {
    switch (state) {
      case TimelineState.next:
        return Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.secondary, width: 4),
          ),
        );
      case TimelineState.passed:
        return Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.surface,
            shape: BoxShape.circle,
          ),
          child: Container(
            width: 14,
            height: 14,
            decoration: const BoxDecoration(
              color: AppColors.secondary,
              shape: BoxShape.circle,
            ),
          ),
        );
      case TimelineState.upcoming:
        return Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.surface,
            shape: BoxShape.circle,
          ),
          child: Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: AppColors.surface,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.lilacLine, width: 3),
            ),
          ),
        );
    }
  }
}
