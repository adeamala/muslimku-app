import 'package:flutter/material.dart';

import 'package:muslimku/core/theme/app_colors.dart';
import 'package:muslimku/shared/widgets/diorama/diorama_widgets.dart';

class IbadahItem {
  const IbadahItem({
    required this.label,
    required this.icon,
    required this.onTap,
    this.isNew = false,
  });

  final String label;

  /// One of the clay icons in `images/3d/`.
  final String icon;
  final VoidCallback onTap;
  final bool isNew;
}

/// 3 x 2 grid of lilac tiles with the 3D clay icons.
class IbadahGrid extends StatelessWidget {
  const IbadahGrid({super.key, required this.items});

  final List<IbadahItem> items;

  @override
  Widget build(BuildContext context) {
    const columns = 3;
    const gap = 12.0;
    final rows = <Widget>[];
    for (var i = 0; i < items.length; i += columns) {
      final rowItems = items.sublist(i, (i + columns).clamp(0, items.length));
      rows.add(
        Padding(
          padding: EdgeInsets.only(top: i == 0 ? 0 : gap),
          child: Row(
            children: [
              for (var j = 0; j < columns; j++) ...[
                if (j > 0) const SizedBox(width: gap),
                Expanded(
                  child: j < rowItems.length
                      ? _IbadahTile(rowItems[j])
                      : const SizedBox.shrink(),
                ),
              ],
            ],
          ),
        ),
      );
    }
    return Column(children: rows);
  }
}

class _IbadahTile extends StatelessWidget {
  const _IbadahTile(this.item);

  final IbadahItem item;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(22);
    return Semantics(
      button: true,
      label: item.isNew ? '${item.label}, fitur baru' : item.label,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: [
            BoxShadow(color: AppColors.lilacShadow, offset: const Offset(0, 5)),
          ],
        ),
        child: Material(
          color: AppColors.lilac,
          borderRadius: radius,
          child: InkWell(
            borderRadius: radius,
            onTap: item.onTap,
            child: SizedBox(
              height: 112,
              child: Stack(
                children: [
                  Positioned(
                    top: 10,
                    left: 8,
                    right: 8,
                    height: 60,
                    child: Image.asset(
                      item.icon,
                      fit: BoxFit.contain,
                      excludeFromSemantics: true,
                    ),
                  ),
                  Positioned(
                    left: 6,
                    right: 6,
                    bottom: 12,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        item.label,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                  ),
                  if (item.isNew)
                    const Positioned(top: 8, right: 8, child: NewBadge()),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
