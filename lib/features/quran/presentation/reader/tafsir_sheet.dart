import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muslimku/core/theme/app_colors.dart';
import 'package:muslimku/features/quran/data/tafsir_repository.dart';
import 'package:muslimku/features/quran/domain/quran_models.dart';
import 'package:muslimku/shared/widgets/senja/senja.dart';

/// Tafsir Kemenag of one ayah, with previous/next inside the sheet.
Future<void> showAyahTafsirSheet(
  BuildContext context, {
  required Surah surah,
  required int ayah,
}) => showSenjaSheet<void>(
  context,
  title: 'Tafsir ${surah.name}',
  scrollable: false,
  builder: (_) => TafsirSheet(surah: surah, initialAyah: ayah),
);

class TafsirSheet extends ConsumerStatefulWidget {
  const TafsirSheet({
    super.key,
    required this.surah,
    required this.initialAyah,
  });

  final Surah surah;
  final int initialAyah;

  @override
  ConsumerState<TafsirSheet> createState() => _TafsirSheetState();
}

class _TafsirSheetState extends ConsumerState<TafsirSheet> {
  late int _ayah = widget.initialAyah;
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _go(int by) {
    setState(() => _ayah = (_ayah + by).clamp(1, widget.surah.verseCount));
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  @override
  Widget build(BuildContext context) {
    final tafsir = ref.watch(surahTafsirProvider(widget.surah.number));
    final maxHeight = MediaQuery.sizeOf(context).height * 0.62;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            SenjaIconButton(
              icon: Icons.chevron_left_rounded,
              tooltip: 'Ayat sebelumnya',
              style: SenjaIconStyle.lilac,
              size: 36,
              iconSize: 22,
              onPressed: _ayah > 1 ? () => _go(-1) : null,
            ),
            Expanded(
              child: Semantics(
                liveRegion: true,
                child: Text(
                  'Ayat $_ayah dari ${widget.surah.verseCount}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
              ),
            ),
            SenjaIconButton(
              icon: Icons.chevron_right_rounded,
              tooltip: 'Ayat berikutnya',
              style: SenjaIconStyle.lilac,
              size: 36,
              iconSize: 22,
              onPressed: _ayah < widget.surah.verseCount ? () => _go(1) : null,
            ),
          ],
        ),
        const SizedBox(height: 10),
        ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: tafsir.when(
            skipLoadingOnRefresh: false,
            data: (data) {
              final text = data.data[_ayah];
              return SingleChildScrollView(
                controller: _scroll,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      text == null || text.isEmpty
                          ? 'Tafsir ayat ini belum tersedia.'
                          : text,
                      style: TextStyle(
                        fontSize: 14.5,
                        height: 1.65,
                        fontWeight: FontWeight.w500,
                        color: AppColors.bodyText,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Tafsir Kemenag RI · sumber: equran.id',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.inkMuted,
                      ),
                    ),
                  ],
                ),
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.only(top: 4),
              child: SenjaSkeletonList(rows: 4),
            ),
            error: (_, _) => Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Tafsir surat ini belum tersimpan. Buka sekali saat ada '
                    'internet; setelah itu bisa dibaca tanpa internet.',
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.inkMuted,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: SenjaSmallButton(
                      label: 'Coba lagi',
                      onTap: () => ref.invalidate(
                        surahTafsirProvider(widget.surah.number),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
