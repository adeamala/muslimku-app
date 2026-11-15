import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muslimku/core/theme/app_colors.dart';
import 'package:muslimku/features/quran/application/quran_progress_provider.dart';
import 'package:muslimku/features/quran/presentation/quran_list_shared.dart';
import 'package:muslimku/shared/widgets/senja/senja.dart';

/// "Ditandai" tab: ayat marked in the reader, newest first. Tap opens the
/// reader at the ayah; the filled bookmark removes the mark (with undo).
class BookmarksTab extends ConsumerWidget {
  const BookmarksTab({super.key, required this.onTab});

  final ValueChanged<int> onTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final marks = _newestFirst(ref.watch(ayahBookmarksProvider));
    final offline = ref.watch(quranOfflineProvider);
    return RefreshIndicator(
      // Marks live on the phone; pulling only checks the connection again.
      onRefresh: () =>
          refreshSurahList(ProviderScope.containerOf(context, listen: false)),
      color: AppColors.secondary,
      child: CustomScrollView(
        primary: false,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          quranTopSliver([
            if (offline) const OfflineBanner(message: quranOfflineMessage),
          ]),
          quranTabBarSliver(selected: QuranTabs.ditandai, onChanged: onTab),
          if (marks.isEmpty)
            const SliverToBoxAdapter(
              child: SenjaEmptyState(
                image: 'images/3d/icon_quran.webp',
                title: 'Belum ada ayat yang ditandai',
                message:
                    'Ketuk ikon penanda di halaman baca untuk menyimpan ayat.',
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverList.builder(
                itemCount: marks.length,
                itemBuilder: (context, i) => _BookmarkRow(mark: marks[i]),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }

  /// Sorted by when they were saved, so undo puts a mark back in its place.
  static List<AyahBookmark> _newestFirst(List<AyahBookmark> marks) {
    final indexed = [for (var i = 0; i < marks.length; i++) (i, marks[i])]
      ..sort((a, b) {
        final byDate = b.$2.savedAt.compareTo(a.$2.savedAt);
        return byDate != 0 ? byDate : a.$1.compareTo(b.$1);
      });
    return [for (final (_, mark) in indexed) mark];
  }
}

class _BookmarkRow extends ConsumerWidget {
  const _BookmarkRow({required this.mark});

  final AyahBookmark mark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SenjaListRow(
      leading: OctagramBadge('${mark.ayah}'),
      title: '${mark.surahName} · Ayat ${mark.ayah}',
      subtitle: mark.snippet.isEmpty ? null : mark.snippet,
      onTap: () => openQuranReader(context, mark.surah, ayah: mark.ayah),
      trailing: SenjaIconButton(
        icon: Icons.bookmark_rounded,
        tooltip: 'Hapus tanda',
        color: AppColors.secondary,
        onPressed: () {
          final bookmarks = ref.read(ayahBookmarksProvider.notifier);
          bookmarks.remove(mark.surah, mark.ayah);
          showUndoSnackBar(
            context,
            'Tanda ${mark.surahName} ayat ${mark.ayah} dihapus',
            () {
              if (!bookmarks.contains(mark.surah, mark.ayah)) {
                bookmarks.toggle(mark);
              }
            },
          );
        },
      ),
    );
  }
}
