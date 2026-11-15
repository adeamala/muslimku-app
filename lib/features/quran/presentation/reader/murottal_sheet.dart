import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muslimku/core/theme/app_colors.dart';
import 'package:muslimku/features/quran/application/murottal_download_provider.dart';
import 'package:muslimku/features/quran/domain/quran_models.dart';
import 'package:muslimku/features/reading/application/reading_settings_provider.dart';
import 'package:muslimku/shared/application/offline_data_provider.dart'
    show formatBytes;
import 'package:muslimku/shared/widgets/senja/senja.dart';

/// "Murottal offline": download the recitation of [surah] by the qari
/// chosen in Pengaturan, ayah by ayah, so it plays without internet.
Future<void> showMurottalSheet(
  BuildContext context,
  Surah surah,
  List<Ayah> ayat,
) {
  return showSenjaSheet<void>(
    context,
    title: 'Murottal offline',
    builder: (context) => _MurottalSheet(surah: surah, ayat: ayat),
  );
}

class _MurottalSheet extends ConsumerWidget {
  const _MurottalSheet({required this.surah, required this.ayat});

  final Surah surah;
  final List<Ayah> ayat;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reciter = ref.watch(readingSettingsProvider.select((s) => s.reciter));
    final notifier = ref.read(murottalDownloadProvider.notifier);
    // Live status from the controller; the first read comes from the phone.
    final live = ref.watch(
      murottalDownloadProvider.select(
        (m) => m[MurottalDownloadController.keyOf(reciter, surah.number)],
      ),
    );
    final initial = ref.watch(surahMurottalProvider((surah.number, ayat)));
    final status = live ?? initial.valueOrNull;
    final note = TextStyle(
      fontSize: 13,
      height: 1.45,
      fontWeight: FontWeight.w500,
      color: AppColors.inkMuted,
    );
    if (status == null) {
      return const SenjaSkeletonList(rows: 2);
    }
    final String line;
    final String action;
    if (status.running) {
      line = 'Mengunduh… ${status.saved} dari ${status.total} ayat';
      action = 'Batal';
    } else if (status.complete) {
      line = 'Tersimpan · ${status.total} ayat · ${formatBytes(status.bytes)}';
      action = 'Hapus dari HP';
    } else if (status.failedAt != null) {
      line =
          'Terhenti di ayat ${status.failedAt} · ${status.saved} dari '
          '${status.total} tersimpan';
      action = 'Lanjutkan unduhan';
    } else if (status.saved > 0) {
      line =
          '${status.saved} dari ${status.total} ayat tersimpan · '
          '${formatBytes(status.bytes)}';
      action = 'Lanjutkan unduhan';
    } else {
      line =
          '${reciter.shortLabel} · ${status.total} ayat · '
          '${formatBytes(estimateMurottalBytes(reciter, status.total))}';
      action = 'Unduh surat ini';
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          surah.name,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: 4),
        Text(line, style: note),
        if (status.running || status.failedAt != null) ...[
          const SizedBox(height: 10),
          SenjaProgressBar(value: status.progress),
        ],
        const SizedBox(height: 14),
        SenjaButton(
          label: action,
          icon: status.complete
              ? Icons.delete_outline_rounded
              : status.running
              ? Icons.close_rounded
              : Icons.download_rounded,
          height: 48,
          onPressed: () {
            if (status.running) {
              notifier.cancel(reciter, surah.number);
            } else if (status.complete) {
              notifier.delete(surah.number, ayat, reciter);
            } else {
              notifier.download(surah.number, ayat, reciter);
            }
          },
        ),
        const SizedBox(height: 10),
        Text(
          'Qari: ${reciter.label}. Ganti qari di Pengaturan › Al-Qur\'an; '
          'setiap qari disimpan terpisah. Ayat yang tersimpan diputar dari '
          'HP, sisanya dari internet.',
          style: note.copyWith(fontSize: 12),
        ),
      ],
    );
  }
}
