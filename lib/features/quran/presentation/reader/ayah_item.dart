import 'package:flutter/material.dart';
import 'package:muslimku/core/theme/app_colors.dart';
import 'package:muslimku/core/theme/app_text_styles.dart';
import 'package:muslimku/features/quran/domain/quran_models.dart';
import 'package:muslimku/features/quran/domain/tajweed.dart';
import 'package:muslimku/features/quran/presentation/reader/reader_text.dart';
import 'package:muslimku/features/quran/presentation/reader/tajweed_style.dart';
import 'package:muslimku/features/reading/application/reading_settings_provider.dart';
import 'package:muslimku/shared/widgets/senja/senja.dart';

/// Border of the ayah being recited.
final _goldLine = AppColors.gold.withValues(alpha: 0.35);

/// One ayah in the reader (design `.ayah`): star number, actions, Arabic,
/// latin and translation. The ayah being recited gets a highlighted card.
class AyahItem extends StatelessWidget {
  const AyahItem({
    super.key,
    required this.ayah,
    required this.palette,
    required this.settings,
    this.current = false,
    this.playing = false,
    this.bookmarked = false,
    this.lastRead = false,
    this.onPlay,
    this.onBookmark,
    this.onShare,
    this.onMore,
    this.tajweed,
  });

  final Ayah ayah;
  final ReadingPalette palette;
  final ReadingSettings settings;

  /// alquran.cloud markup of this ayah when "Tajwid berwarna" is on and the
  /// surah's markup is available; null shows the plain Kemenag text.
  final String? tajweed;

  /// The murottal is on this ayah (playing or paused).
  final bool current;
  final bool playing;
  final bool bookmarked;

  /// Shows the "Terakhir dibaca" tag.
  final bool lastRead;
  final VoidCallback? onPlay;
  final VoidCallback? onBookmark;
  final VoidCallback? onShare;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    final dark = palette.isDark;
    final translation = cleanTranslation(ayah.translation);
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            OctagramBadge('${ayah.number}', size: 32, gold: dark),
            const SizedBox(width: 8),
            Expanded(
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  if (current)
                    _Label(
                      playing ? 'Sedang diputar' : 'Dijeda',
                      background: dark
                          ? AppColors.gold.withValues(alpha: 0.16)
                          : AppColors.lilac,
                      color: dark ? AppColors.gold : AppColors.secondary,
                    ),
                  if (lastRead)
                    _Label(
                      'Terakhir dibaca',
                      icon: Icons.bookmark_rounded,
                      background: dark ? AppColors.gold : AppColors.primary,
                      color: dark ? AppColors.duskNight : AppColors.ink,
                    ),
                ],
              ),
            ),
            _PlayButton(
              number: ayah.number,
              current: current,
              playing: playing,
              palette: palette,
              onPressed: onPlay,
            ),
            SenjaIconButton(
              icon: bookmarked
                  ? Icons.bookmark_rounded
                  : Icons.bookmark_border_rounded,
              tooltip: bookmarked
                  ? 'Hapus tanda ayat ${ayah.number}'
                  : 'Tandai ayat ${ayah.number}',
              color: bookmarked ? palette.accent : palette.muted,
              iconSize: 20,
              onPressed: onBookmark,
            ),
            SenjaIconButton(
              icon: Icons.ios_share_rounded,
              tooltip: 'Bagikan ayat ${ayah.number}',
              color: palette.muted,
              iconSize: 19,
              onPressed: onShare,
            ),
            SenjaIconButton(
              icon: Icons.more_horiz_rounded,
              tooltip: 'Lainnya untuk ayat ${ayah.number}',
              color: palette.muted,
              iconSize: 21,
              onPressed: onMore,
            ),
          ],
        ),
        // Stacked harakat rise high above Amiri's line box: 18 px from the
        // badge (the action row is 40 px tall for the tap targets).
        const SizedBox(height: 14),
        if (tajweed != null)
          Text.rich(
            tajweedTextSpan(
              parseTajweed(tajweed!),
              TextStyle(
                fontFamily: AppTextStyles.arabicFontFamily,
                fontSize: settings.arabicSize,
                height: 1.9,
                color: current && !dark ? AppColors.ayahDeep : palette.arabic,
              ),
            ),
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.right,
          )
        else
          ArabicText(
            ayah.arab,
            size: settings.arabicSize,
            color: current && !dark ? AppColors.ayahDeep : palette.arabic,
          ),
        if (settings.showLatin && ayah.latin.isNotEmpty)
          Text(
            ayah.latin,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.5,
              fontWeight: FontWeight.w600,
              color: palette.latin,
            ),
          ),
        if (settings.showTranslation && translation.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(
              translation,
              style: TextStyle(
                fontSize: 14.5,
                height: 1.55,
                fontWeight: FontWeight.w500,
                color: palette.translation,
              ),
            ),
          ),
      ],
    );
    if (current) {
      return Container(
        margin: const EdgeInsets.fromLTRB(8, 8, 8, 0),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
        decoration: BoxDecoration(
          color: palette.highlight,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: dark ? _goldLine : AppColors.lilacShadow,
            width: 1.5,
          ),
        ),
        child: body,
      );
    }
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.only(top: 12, bottom: 14),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: palette.line)),
      ),
      child: body,
    );
  }
}

/// Play button of an ayah; a lime (gold at night) disc while it is recited.
class _PlayButton extends StatelessWidget {
  const _PlayButton({
    required this.number,
    required this.current,
    required this.playing,
    required this.palette,
    required this.onPressed,
  });

  final int number;
  final bool current;
  final bool playing;
  final ReadingPalette palette;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final tooltip = current && playing
        ? 'Jeda ayat $number'
        : 'Putar ayat $number';
    if (!current) {
      return SenjaIconButton(
        icon: Icons.play_arrow_rounded,
        tooltip: tooltip,
        color: palette.muted,
        iconSize: 22,
        onPressed: onPressed,
      );
    }
    final dark = palette.isDark;
    return Tooltip(
      message: tooltip,
      child: SizedBox.square(
        dimension: 40,
        child: Center(
          child: Material(
            color: dark ? AppColors.gold : AppColors.primary,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onPressed,
              child: SizedBox.square(
                dimension: 32,
                child: Icon(
                  playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  size: 19,
                  color: dark ? AppColors.duskNight : AppColors.ink,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Small rounded label next to the ayah number.
class _Label extends StatelessWidget {
  const _Label(
    this.text, {
    required this.background,
    required this.color,
    this.icon,
  });

  final String text;
  final Color background;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
          ],
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
