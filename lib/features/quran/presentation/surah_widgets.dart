import 'package:flutter/material.dart';
import 'package:muslimku/core/theme/app_colors.dart';
import 'package:muslimku/core/theme/app_text_styles.dart';
import 'package:muslimku/features/quran/application/quran_progress_provider.dart';
import 'package:muslimku/features/quran/domain/quran_models.dart';
import 'package:muslimku/features/quran/presentation/quran_list_logic.dart';
import 'package:muslimku/features/quran/presentation/quran_list_shared.dart';
import 'package:muslimku/shared/widgets/senja/senja.dart';

/// One surah in the list (design `q1`/`o1`): star number, name, meaning and
/// revelation, Arabic name over the ayat count. While offline [saved] adds a
/// check (saved on the phone) or a cloud, and unsaved rows are dimmed.
class SurahRow extends StatelessWidget {
  const SurahRow({
    super.key,
    required this.surah,
    required this.onTap,
    this.saved,
  });

  final Surah surah;
  final VoidCallback onTap;

  /// Null while online.
  final bool? saved;

  @override
  Widget build(BuildContext context) {
    final saved = this.saved;
    return SenjaListRow(
      leading: OctagramBadge('${surah.number}'),
      title: surah.name,
      subtitle: '${surah.meaning} · ${surah.revelation}',
      dimmed: saved == false,
      onTap: onTap,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (saved != null) ...[
            Icon(
              saved ? Icons.check_circle_rounded : Icons.cloud_outlined,
              size: 18,
              color: saved ? AppColors.secondary : AppColors.inkMuted,
              semanticLabel: saved ? 'Tersimpan di HP' : 'Belum tersimpan',
            ),
            const SizedBox(width: 14),
          ],
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              ArabicText(
                surah.arabicName,
                size: 22,
                height: 1.25,
                color: AppColors.secondary,
                maxLines: 1,
              ),
              Text(
                '${surah.verseCount} ayat',
                style: TextStyle(
                  fontSize: 11,
                  height: 1.1,
                  fontWeight: FontWeight.w700,
                  color: AppColors.inkMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// "Lanjutkan membaca" (design `q1`): the last read surah with a thin lime
/// progress bar, its Arabic name as a faint watermark and a play button.
class ContinueReadingCard extends StatelessWidget {
  const ContinueReadingCard({
    super.key,
    required this.lastRead,
    required this.title,
    required this.onOpen,
    this.arabicName,
  });

  final LastRead lastRead;
  final String title;
  final String? arabicName;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final arabic = arabicName ?? '';
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 122),
      child: SenjaFeatureCard(
        caption: 'Lanjutkan membaca',
        title: title,
        subtitle: lastReadDetail(lastRead),
        onTap: onOpen,
        watermark: arabic.isEmpty
            ? null
            : Positioned(
                right: 84,
                top: -6,
                child: ExcludeSemantics(
                  child: MediaQuery.withNoTextScaling(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 170),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: ArabicText(
                          arabic,
                          size: 76,
                          height: 1.4,
                          color: Colors.white.withValues(alpha: 0.14),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
        trailing: SenjaGoButton(
          icon: Icons.play_arrow_rounded,
          tooltip: 'Lanjutkan membaca',
          onPressed: onOpen,
        ),
        child: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: SizedBox(
            width: 190,
            child: SenjaProgressBar(value: lastRead.progress, onPurple: true),
          ),
        ),
      ),
    );
  }
}

/// "Saring surat": Semua / Makkiyyah / Madaniyyah with their counts.
Future<RevelationFilter?> showSurahFilterSheet(
  BuildContext context, {
  required RevelationFilter selected,
  required List<Surah> surahs,
}) {
  return showSenjaSheet<RevelationFilter>(
    context,
    title: 'Saring surat',
    builder: (context) => QuranTextDefaults(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final filter in RevelationFilter.values)
            _FilterOption(
              label: filter.label,
              count: surahs.isEmpty
                  ? null
                  : surahs.where(filter.accepts).length,
              selected: filter == selected,
              onTap: () => Navigator.pop(context, filter),
            ),
        ],
      ),
    ),
  );
}

class _FilterOption extends StatelessWidget {
  const _FilterOption({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int? count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          constraints: const BoxConstraints(minHeight: 54),
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.lilacLine)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
              ),
              if (count != null)
                Text(
                  '$count surat',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.inkMuted,
                  ),
                ),
              const SizedBox(width: 12),
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                size: 22,
                color: selected ? AppColors.secondary : AppColors.lilacShadow,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shown when the search or filter leaves no surah.
class NoSurahMatch extends StatelessWidget {
  const NoSurahMatch({super.key, required this.onClear});

  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 30, 28, 0),
      child: Column(
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 34,
            color: AppColors.lilacShadow,
          ),
          const SizedBox(height: 10),
          Text(
            'Tidak ada surat yang cocok',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Coba nama surat, nomor 1–114, atau artinya.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.45,
              fontWeight: FontWeight.w500,
              color: AppColors.inkMuted,
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: onClear,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.secondary,
              minimumSize: const Size(0, 44),
              textStyle: const TextStyle(
                fontFamily: AppTextStyles.fontFamily,
                fontSize: 13.5,
                letterSpacing: 0,
                fontWeight: FontWeight.w800,
              ),
            ),
            child: const Text('Hapus pencarian'),
          ),
        ],
      ),
    );
  }
}
