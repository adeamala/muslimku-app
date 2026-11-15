import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muslimku/core/theme/app_colors.dart';
import 'package:muslimku/core/theme/app_text_styles.dart';
import 'package:muslimku/features/quran/data/quran_repository.dart';
import 'package:muslimku/features/quran/presentation/quran_list_logic.dart';
import 'package:muslimku/shared/widgets/senja/senja.dart';

/// "Simpan Al-Qur'an di HP" (design `o1`): saved surahs out of 114, a purple
/// progress bar, the saved size and Unduh / Lanjutkan / Batal.
class QuranDownloadCard extends ConsumerWidget {
  const QuranDownloadCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(quranDownloadProvider);
    final notifier = ref.read(quranDownloadProvider.notifier);
    final action = downloadActionFor(state);
    final error = state.error;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.lilacLine, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  "Simpan Al-Qur'an di HP",
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${state.storedSurahs}/${QuranRepository.totalSurahs}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.secondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          SenjaProgressBar(value: state.progress, height: 7),
          const SizedBox(height: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 30),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    downloadCaption(state),
                    style: TextStyle(
                      fontSize: 11.5,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                      color: AppColors.inkMuted,
                    ),
                  ),
                ),
                if (action != DownloadAction.none) ...[
                  const SizedBox(width: 10),
                  _DownloadButton(
                    action: action,
                    onPressed: action == DownloadAction.cancel
                        ? notifier.cancel
                        : notifier.start,
                  ),
                ],
              ],
            ),
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                error,
                style: const TextStyle(
                  fontSize: 11.5,
                  height: 1.35,
                  fontWeight: FontWeight.w700,
                  color: AppColors.offlineAccent,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Lime pill to start or resume, white outline to cancel (40 px tap target).
class _DownloadButton extends StatelessWidget {
  const _DownloadButton({required this.action, required this.onPressed});

  final DownloadAction action;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final cancel = action == DownloadAction.cancel;
    return Semantics(
      container: true,
      button: true,
      child: Material(
        color: cancel ? Colors.white : AppColors.primary,
        shape: StadiumBorder(
          side: cancel
              ? BorderSide(color: AppColors.lilacLine, width: 1.5)
              : BorderSide.none,
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onPressed,
          child: Container(
            constraints: const BoxConstraints(minHeight: 40),
            padding: const EdgeInsets.only(left: 11, right: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  cancel ? Icons.close_rounded : Icons.download_rounded,
                  size: 17,
                  color: AppColors.ink,
                ),
                const SizedBox(width: 5),
                Text(
                  action.label,
                  style: TextStyle(
                    fontSize: 12.5,
                    letterSpacing: 0,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Quiet link after the full surah list while online: saves every surah that
/// is not on the phone yet. Hidden once all are saved or while downloading
/// (the card at the top shows the progress then).
class SaveAllFooter extends ConsumerWidget {
  const SaveAllFooter({super.key, required this.onStarted});

  /// Called after the download started, e.g. to scroll to the progress card.
  final VoidCallback onStarted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(quranDownloadProvider);
    if (state.complete || state.running) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Center(
        child: TextButton.icon(
          onPressed: () {
            ref.read(quranDownloadProvider.notifier).start();
            onStarted();
          },
          style: TextButton.styleFrom(
            foregroundColor: AppColors.secondary,
            minimumSize: const Size(0, 44),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            textStyle: const TextStyle(
              fontFamily: AppTextStyles.fontFamily,
              fontSize: 13,
              letterSpacing: 0,
              fontWeight: FontWeight.w700,
            ),
          ),
          icon: const Icon(Icons.download_rounded, size: 18),
          label: const Text(
            'Simpan semua surat di HP ($quranTotalSizeLabel)',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
