import 'package:flutter/material.dart';
import 'package:muslimku/core/theme/app_colors.dart';
import 'package:muslimku/core/theme/app_text_styles.dart';
import 'package:muslimku/features/asmaul_husna/application/asmaul_husna_provider.dart';
import 'package:muslimku/features/asmaul_husna/presentation/husna_actions.dart';
import 'package:muslimku/shared/widgets/senja/senja.dart';

/// Grid card of one name (design `.hc`). In Hafalan mode the meaning stays
/// hidden until [showMeaning] is set.
class HusnaNameCard extends StatelessWidget {
  const HusnaNameCard({
    super.key,
    required this.name,
    required this.showMeaning,
    required this.onTap,
  });

  final HusnaName name;
  final bool showMeaning;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SenjaCard(
      radius: 20,
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: Stack(
        // Fill the card: a loose Stack would shrink the column to its widest
        // text and leave it on the left.
        fit: StackFit.expand,
        children: [
          Positioned(
            left: 10,
            top: 10,
            child: OctagramBadge('${name.number}', size: 28),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 14, 10, 8),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 2, 16, 0),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      name.arabic,
                      textDirection: TextDirection.rtl,
                      style: TextStyle(
                        fontFamily: AppTextStyles.arabicFontFamily,
                        fontSize: 28,
                        height: 1.55,
                        // Deep purple by day, cream by night.
                        color: AppColors.dark
                            ? AppColors.nightCream
                            : AppColors.ayahDeep,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 1),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    name.latin,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  showMeaning ? name.meaning : 'Ketuk untuk melihat arti',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.3,
                    fontWeight: showMeaning ? FontWeight.w600 : FontWeight.w700,
                    color: showMeaning
                        ? AppColors.inkMuted
                        : AppColors.secondary,
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

/// Bottom sheet of one name: big Arabic, meaning, "Dzikir 33×" and "Bagikan".
Future<void> showHusnaSheet(BuildContext context, HusnaName name) {
  return showSenjaSheet<void>(
    context,
    title: name.latin,
    titleAction: SenjaTag('No. ${name.number}'),
    builder: (sheetContext) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        ArabicCard(text: name.arabic, size: 46, align: TextAlign.center),
        const SizedBox(height: 18),
        const Text(
          'ARTINYA',
          style: TextStyle(
            fontSize: 11.5,
            letterSpacing: 1.1,
            fontWeight: FontWeight.w800,
            color: AppColors.secondary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          name.meaning,
          style: TextStyle(
            fontSize: 17,
            height: 1.5,
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            Expanded(
              child: SenjaButton(
                label: 'Dzikir 33×',
                icon: Icons.blur_circular_rounded,
                style: SenjaButtonStyle.lime,
                onPressed: () {
                  Navigator.of(sheetContext).pop();
                  openHusnaDzikir(context, name);
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SenjaButton(
                label: 'Bagikan',
                icon: Icons.ios_share_rounded,
                style: SenjaButtonStyle.outline,
                onPressed: () => shareHusna(name),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
