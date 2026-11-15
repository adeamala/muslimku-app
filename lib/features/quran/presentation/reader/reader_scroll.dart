import 'dart:math' as math;

import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

/// Ayat on screen in the reader list, where item 0 is the surah header,
/// items 1..ayahCount are the ayat and the last item is the footer.
class VisibleAyat {
  const VisibleAyat(this.first, this.visible);

  /// Topmost ayah below the app bar (the header counts as ayah 1, the footer
  /// as the last ayah), or null before the list is laid out.
  final int? first;

  /// Ayah numbers at least partly on screen, ascending.
  final List<int> visible;
}

/// [top] and [bottom] bound the readable part of the viewport (0–1), e.g.
/// [top] is the app bar height divided by the viewport height. An item needs
/// [minVisible] of the viewport on screen to count.
VisibleAyat visibleAyat(
  Iterable<ItemPosition> positions, {
  required int ayahCount,
  double top = 0,
  double bottom = 1,
  double minVisible = 0.025,
}) {
  final onScreen = [
    for (final p in positions)
      if (p.itemTrailingEdge > top + minVisible &&
          p.itemLeadingEdge < bottom - minVisible)
        p.index,
  ];
  if (ayahCount <= 0 || onScreen.isEmpty) return const VisibleAyat(null, []);
  final first = onScreen.map((i) => i.clamp(1, ayahCount)).reduce(math.min);
  final ayat = [
    for (final i in onScreen)
      if (i >= 1 && i <= ayahCount) i,
  ]..sort();
  return VisibleAyat(first, ayat);
}
