import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muslimku/core/storage/content_cache.dart';
import 'package:muslimku/core/theme/app_colors.dart';
import 'package:muslimku/core/theme/app_text_styles.dart';
import 'package:muslimku/features/quran/application/quran_progress_provider.dart';
import 'package:muslimku/features/quran/data/quran_repository.dart';
import 'package:muslimku/features/quran/presentation/quran_reader_screen.dart';
import 'package:muslimku/shared/widgets/senja/senja.dart';

/// Tabs of the Al-Qur'an screen ("Surat | Juz | Tema | Ditandai").
abstract final class QuranTabs {
  static const surat = 0;
  static const juz = 1;
  static const tema = 2;
  static const ditandai = 3;
  static const count = 4;
}

const quranOfflineMessage = 'Surat yang sudah tersimpan tetap bisa dibaca.';

/// Opens the reader at [ayah] of [surah].
Future<void> openQuranReader(BuildContext context, int surah, {int ayah = 1}) {
  return Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => QuranReaderScreen(surahNumber: surah, initialAyah: ayah),
    ),
  );
}

/// "Sedang offline" on the Al-Qur'an tab: the last MyQuran request failed, or
/// the surah list is the saved copy because its refresh failed.
final quranOfflineProvider = Provider<bool>(
  (ref) =>
      ref.watch(networkStatusProvider) ||
      (ref.watch(surahListProvider).valueOrNull?.offline ?? false),
);

/// Downloads the surah list again (pull to refresh, "Coba lagi" on the
/// banner). Without internet the saved copy stays and the banner shows.
Future<void> refreshSurahList(ProviderContainer container) async {
  try {
    await container.read(quranRepositoryProvider).surahs(refresh: true);
  } catch (_) {
    return; // nothing saved and no internet: keep what is shown
  }
  container
    ..invalidate(surahListProvider)
    ..invalidate(storedSurahsProvider);
  await container
      .read(surahListProvider.future)
      .then<void>((_) {}, onError: (_) {});
}

/// Like [refreshSurahList], for the juz grid.
Future<void> refreshJuzList(ProviderContainer container) async {
  try {
    await container.read(quranRepositoryProvider).juzList(refresh: true);
  } catch (_) {
    return;
  }
  container.invalidate(juzListProvider);
  await container
      .read(juzListProvider.future)
      .then<void>((_) {}, onError: (_) {});
}

/// Snackbar with "Urungkan" (undo).
void showUndoSnackBar(
  BuildContext context,
  String message,
  VoidCallback onUndo,
) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.ink,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        action: SnackBarAction(
          label: 'Urungkan',
          textColor: AppColors.primary,
          onPressed: onUndo,
        ),
      ),
    );
}

/// Text defaults of the design (font's own line height, no extra tracking).
/// Without this, Senja texts inherit Material 3 `bodyMedium` geometry
/// (height 1.43, letter spacing 0.25), which makes rows taller and wider
/// than the mock.
class QuranTextDefaults extends StatelessWidget {
  const QuranTextDefaults({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DefaultTextStyle(
      style: TextStyle(
        fontFamily: AppTextStyles.fontFamily,
        fontSize: 14,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
        color: AppColors.ink,
      ),
      child: child,
    );
  }
}

/// What sits above the tab bar (offline banner, cards, search), 14 px apart;
/// without anything only the gap to the top of the sheet.
Widget quranTopSliver(List<Widget> children) {
  if (children.isEmpty) {
    return const SliverToBoxAdapter(
      child: SizedBox(height: 20 - QuranTabBarDelegate.gapAbove),
    );
  }
  return SliverPadding(
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
    sliver: SliverList.list(
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(height: 14),
          children[i],
        ],
      ],
    ),
  );
}

/// "Surat | Juz | Ditandai 3", pinned to the top of the sheet while the list
/// scrolls under it.
Widget quranTabBarSliver({
  required int selected,
  required ValueChanged<int> onChanged,
}) => SliverPersistentHeader(
  pinned: true,
  delegate: QuranTabBarDelegate(selected: selected, onChanged: onChanged),
);

class QuranTabBarDelegate extends SliverPersistentHeaderDelegate {
  QuranTabBarDelegate({required this.selected, required this.onChanged});

  static const gapAbove = 14.0;
  static const gapBelow = 6.0;

  /// The segmented control is 46 px at every text size (labels scale down).
  static const extent = gapAbove + 46 + gapBelow;

  final int selected;
  final ValueChanged<int> onChanged;

  @override
  double get minExtent => extent;

  @override
  double get maxExtent => extent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return ColoredBox(
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, gapAbove, 20, gapBelow),
        child: _QuranTabBar(selected: selected, onChanged: onChanged),
      ),
    );
  }

  @override
  bool shouldRebuild(QuranTabBarDelegate oldDelegate) =>
      oldDelegate.selected != selected || oldDelegate.onChanged != onChanged;
}

class _QuranTabBar extends ConsumerWidget {
  const _QuranTabBar({required this.selected, required this.onChanged});

  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final marked = ref.watch(ayahBookmarksProvider.select((b) => b.length));
    return SenjaSegmented(
      items: [
        const SenjaSegment('Surat'),
        const SenjaSegment('Juz'),
        const SenjaSegment('Tema'),
        SenjaSegment('Ditandai', count: marked > 0 ? marked : null),
      ],
      selected: selected,
      onChanged: onChanged,
    );
  }
}
