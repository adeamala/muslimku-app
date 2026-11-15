import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muslimku/core/storage/content_cache.dart';
import 'package:muslimku/core/theme/app_colors.dart';
import 'package:muslimku/features/quran/application/quran_progress_provider.dart';
import 'package:muslimku/features/quran/data/quran_repository.dart';
import 'package:muslimku/features/quran/domain/quran_models.dart';
import 'package:muslimku/features/quran/presentation/ayah_search_screen.dart';
import 'package:muslimku/features/quran/presentation/quran_download_widgets.dart';
import 'package:muslimku/features/quran/presentation/quran_list_logic.dart';
import 'package:muslimku/features/quran/presentation/quran_list_shared.dart';
import 'package:muslimku/features/quran/presentation/surah_widgets.dart';
import 'package:muslimku/shared/widgets/senja/senja.dart';

/// "Surat" tab (design `q1`, offline `o1`): search with the revelation
/// filter, "Lanjutkan membaca", the tab bar and the 114 surahs.
class SurahTab extends ConsumerStatefulWidget {
  const SurahTab({super.key, required this.onTab});

  final ValueChanged<int> onTab;

  @override
  ConsumerState<SurahTab> createState() => _SurahTabState();
}

class _SurahTabState extends ConsumerState<SurahTab> {
  final _search = TextEditingController();
  final _scroll = ScrollController();
  String _query = '';
  RevelationFilter _filter = RevelationFilter.all;

  bool get _searching => _query.trim().isNotEmpty;

  @override
  void dispose() {
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _refresh() =>
      refreshSurahList(ProviderScope.containerOf(context, listen: false));

  void _clearQuery() {
    _search.clear();
    setState(() => _query = '');
  }

  void _clearAll() {
    _search.clear();
    setState(() {
      _query = '';
      _filter = RevelationFilter.all;
    });
  }

  Future<void> _pickFilter(List<Surah> surahs) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final picked = await showSurahFilterSheet(
      context,
      selected: _filter,
      surahs: surahs,
    );
    if (picked != null && mounted) setState(() => _filter = picked);
  }

  /// Shows the progress card after "Simpan semua surat" at the list's end.
  void _scrollToTop() {
    if (!_scroll.hasClients) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _scroll.jumpTo(0);
    } else {
      _scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = ref.watch(surahListProvider);
    final surahs = list.valueOrNull?.data;
    final offline = ref.watch(quranOfflineProvider);
    final downloading = ref.watch(
      quranDownloadProvider.select((s) => s.running),
    );
    final lastRead = ref.watch(lastReadProvider);
    return RefreshIndicator(
      onRefresh: _refresh,
      color: AppColors.secondary,
      child: CustomScrollView(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: [
          quranTopSliver([
            if (offline) const OfflineBanner(message: quranOfflineMessage),
            if (offline || downloading) const QuranDownloadCard(),
            _searchField(surahs ?? const []),
            if (!_searching) const AyahSearchLink(),
            if (lastRead != null && !_searching)
              _continueCard(lastRead, surahs),
          ]),
          quranTabBarSliver(selected: QuranTabs.surat, onChanged: widget.onTab),
          ..._list(list, offline),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }

  Widget _searchField(List<Surah> surahs) {
    return SenjaSearchField(
      hint: 'Cari surat, nomor, atau arti',
      controller: _search,
      onChanged: (value) => setState(() => _query = value),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_searching)
            SenjaIconButton(
              icon: Icons.close_rounded,
              tooltip: 'Hapus teks pencarian',
              color: AppColors.inkMuted,
              iconSize: 19,
              onPressed: _clearQuery,
            ),
          SenjaSearchAction(
            icon: Icons.tune_rounded,
            tooltip: 'Saring surat',
            active: _filter != RevelationFilter.all,
            onTap: () => _pickFilter(surahs),
          ),
        ],
      ),
    );
  }

  Widget _continueCard(LastRead lastRead, List<Surah>? surahs) {
    final surah = surahs?.where((s) => s.number == lastRead.surah).firstOrNull;
    final title = lastRead.surahName.isNotEmpty
        ? lastRead.surahName
        : surah?.name ?? 'Surat ${lastRead.surah}';
    return ContinueReadingCard(
      lastRead: lastRead,
      title: title,
      arabicName: surah?.arabicName,
      onOpen: () =>
          openQuranReader(context, lastRead.surah, ayah: lastRead.ayah),
    );
  }

  List<Widget> _list(AsyncValue<Cached<List<Surah>>> list, bool offline) {
    final surahs = list.valueOrNull?.data;
    if (surahs == null) {
      if (list.hasError && !list.isLoading) {
        return [
          SliverToBoxAdapter(
            child: SenjaEmptyState(
              image: 'images/3d/icon_quran.webp',
              badgeIcon: Icons.wifi_off_rounded,
              title: 'Daftar surat belum bisa dimuat',
              message: 'Periksa internet lalu coba lagi.',
              primaryLabel: 'Coba lagi',
              onPrimary: () => ref.invalidate(surahListProvider),
            ),
          ),
        ];
      }
      return const [
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverToBoxAdapter(child: SenjaSkeletonList()),
        ),
      ];
    }
    final shown = filterSurahs(surahs, query: _query, filter: _filter);
    if (shown.isEmpty) {
      return [SliverToBoxAdapter(child: NoSurahMatch(onClear: _clearAll))];
    }
    final saved = offline
        ? ref.watch(storedSurahsProvider).valueOrNull ?? const <int>{}
        : null;
    final complete = !_searching && _filter == RevelationFilter.all;
    return [
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        sliver: SliverList.builder(
          itemCount: shown.length,
          itemBuilder: (context, i) {
            final surah = shown[i];
            return SurahRow(
              surah: surah,
              saved: saved?.contains(surah.number),
              onTap: () => openQuranReader(context, surah.number),
            );
          },
        ),
      ),
      if (!offline && complete)
        SliverToBoxAdapter(child: SaveAllFooter(onStarted: _scrollToTop)),
    ];
  }
}
