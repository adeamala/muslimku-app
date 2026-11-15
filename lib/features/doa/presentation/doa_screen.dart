import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muslimku/core/storage/content_cache.dart';
import 'package:muslimku/core/theme/app_colors.dart';
import 'package:muslimku/features/doa/application/doa_provider.dart';
import 'package:muslimku/features/doa/presentation/doa_detail_screen.dart';
import 'package:muslimku/features/doa/presentation/doa_widgets.dart';
import 'package:muslimku/shared/application/favorites_provider.dart';
import 'package:muslimku/shared/widgets/senja/senja.dart';

/// Doa tab (design-v2 d1): search, categories, favourites and every doa.
class DoaScreen extends ConsumerStatefulWidget {
  const DoaScreen({super.key});

  @override
  ConsumerState<DoaScreen> createState() => _DoaScreenState();
}

class _DoaScreenState extends ConsumerState<DoaScreen> {
  final _search = TextEditingController();
  String _query = '';
  String? _category;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    ref.read(doaRefreshProvider.notifier).state++;
    try {
      await ref.read(doaListProvider.future);
    } catch (_) {
      // The error state offers "Coba lagi".
    }
  }

  void _open(List<Doa> list, int index) {
    FocusScope.of(context).unfocus();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DoaDetailScreen(doas: list, index: index),
      ),
    );
  }

  void _toggleFavourite(Doa doa) =>
      ref.read(favoritesProvider('doa').notifier).toggle(doa.key);

  @override
  Widget build(BuildContext context) {
    final list = ref.watch(doaListProvider);
    final count = list.valueOrNull?.data.length;
    return SenjaTabScaffold(
      title: 'Doa',
      subtitle: count == null ? 'Kumpulan doa pilihan' : '$count doa pilihan',
      hero: 'images/3d/icon_doa.webp',
      heroWidth: 146,
      heroTop: 46,
      heroRight: 14,
      body: list.when(
        skipLoadingOnReload: true,
        data: _content,
        loading: () => const SenjaSkeletonList(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 0),
        ),
        error: (_, _) => SenjaEmptyState(
          image: 'images/3d/icon_doa.webp',
          badgeIcon: Icons.wifi_off_rounded,
          title: 'Doa belum tersimpan',
          message:
              'Buka sekali saat ada internet. Setelah itu semua doa bisa '
              'dibaca kapan saja, tanpa kuota.',
          primaryLabel: 'Coba lagi',
          onPrimary: _refresh,
        ),
      ),
    );
  }

  Widget _content(Cached<List<Doa>> cached) {
    final all = cached.data;
    final favourites = favouriteDoas(all, ref.watch(favoritesProvider('doa')));
    final favouriteKeys = {for (final d in favourites) d.key};
    final shown = filterDoa(all, category: _category, query: _query);
    final searching = _query.trim().isNotEmpty;
    final offline = cached.offline || ref.watch(networkStatusProvider);

    return RefreshIndicator(
      color: AppColors.secondary,
      onRefresh: _refresh,
      child: CustomScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
            sliver: SliverList.list(
              children: [
                if (offline) ...[
                  OfflineBanner(
                    message: 'Doa tetap bisa dibaca dari data tersimpan.',
                    savedAt: cached.savedAt,
                    onRetry: _refresh,
                  ),
                  const SizedBox(height: 14),
                ],
                SenjaSearchField(
                  hint: 'Cari doa… mis. makan, tidur, masjid',
                  controller: _search,
                  onChanged: (value) => setState(() => _query = value),
                  trailing: _query.isEmpty
                      ? null
                      : SenjaSearchAction(
                          icon: Icons.close_rounded,
                          tooltip: 'Hapus pencarian',
                          onTap: () => setState(() {
                            _search.clear();
                            _query = '';
                          }),
                        ),
                ),
              ],
            ),
          ),
          SliverToBoxAdapter(
            child: _CategoryChips(
              categories: doaCategories(all),
              total: all.length,
              selected: _category,
              onSelected: (category) => setState(() => _category = category),
            ),
          ),
          if (favourites.isNotEmpty && !searching) ...[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
              sliver: SliverToBoxAdapter(
                child: SenjaSectionTitle(
                  'Favorit',
                  trailing: 'Lihat semua',
                  onTrailing: () => _showFavourites(all),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: MediaQuery.textScalerOf(context).scale(92),
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: favourites.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (context, i) => DoaFavouriteCard(
                    doa: favourites[i],
                    onTap: () => _open(favourites, i),
                  ),
                ),
              ),
            ),
          ],
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              20,
              favourites.isNotEmpty && !searching ? 18 : 14,
              20,
              6,
            ),
            sliver: SliverToBoxAdapter(
              child: SenjaSectionTitle(
                searching
                    ? 'Hasil pencarian'
                    : _category == null
                    ? 'Semua doa'
                    : 'Doa ${doaCategoryLabel(_category!)}',
                trailing: '${shown.length}',
              ),
            ),
          ),
          if (shown.isEmpty)
            const SliverToBoxAdapter(child: _NoResults())
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              sliver: SliverList.builder(
                itemCount: shown.length,
                itemBuilder: (context, i) {
                  final doa = shown[i];
                  final favourite = favouriteKeys.contains(doa.key);
                  return SenjaListRow(
                    title: doa.title,
                    subtitle: doa.categoryLabel,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    trailing: DoaStarButton(
                      favourite: favourite,
                      onPressed: () => _toggleFavourite(doa),
                    ),
                    onTap: () => _open(shown, i),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  void _showFavourites(List<Doa> all) {
    showSenjaSheet<void>(
      context,
      title: 'Doa favorit',
      builder: (sheetContext) => Consumer(
        builder: (context, ref, _) {
          final favourites = favouriteDoas(
            all,
            ref.watch(favoritesProvider('doa')),
          );
          if (favourites.isEmpty) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'Belum ada doa favorit. Ketuk bintang di samping doa untuk '
                'menyimpannya di sini.',
                style: TextStyle(fontSize: 13.5, color: AppColors.inkMuted),
              ),
            );
          }
          return Column(
            children: [
              for (var i = 0; i < favourites.length; i++)
                SenjaListRow(
                  title: favourites[i].title,
                  subtitle: favourites[i].categoryLabel,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  trailing: DoaStarButton(
                    favourite: true,
                    onPressed: () => _toggleFavourite(favourites[i]),
                  ),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _open(favourites, i);
                  },
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Horizontal category chips ("Semua 108", "Harian 34", …). The right edge
/// fades while more chips are hidden there.
class _CategoryChips extends StatefulWidget {
  const _CategoryChips({
    required this.categories,
    required this.total,
    required this.selected,
    required this.onSelected,
  });

  final List<DoaCategory> categories;
  final int total;
  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  State<_CategoryChips> createState() => _CategoryChipsState();
}

class _CategoryChipsState extends State<_CategoryChips> {
  bool _moreRight = true;

  bool _onScroll(ScrollMetrics metrics) {
    final more = metrics.extentAfter > 4;
    if (more != _moreRight) setState(() => _moreRight = more);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final chips = <(String?, String, int)>[
      (null, 'Semua', widget.total),
      for (final c in widget.categories) (c.key, c.label, c.count),
    ];
    final list = NotificationListener<ScrollMetricsNotification>(
      onNotification: (n) => _onScroll(n.metrics),
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) => _onScroll(n.metrics),
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: chips.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (context, i) {
            final (key, label, count) = chips[i];
            void select() => widget.onSelected(key);
            // A 44 px tall tap area around the 36 px chip.
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: select,
              child: Center(
                child: SenjaChip(
                  label: label,
                  count: count,
                  selected: widget.selected == key,
                  onTap: select,
                ),
              ),
            );
          },
        ),
      ),
    );
    return SizedBox(
      height: 44,
      // Always masked (only the gradient changes) so the list keeps its
      // scroll position.
      child: ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (rect) => LinearGradient(
          colors: [
            Colors.black,
            Colors.black,
            _moreRight ? Colors.transparent : Colors.black,
          ],
          stops: const [0, 0.82, 1],
        ).createShader(rect),
        child: list,
      ),
    );
  }
}

class _NoResults extends StatelessWidget {
  const _NoResults();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 32),
      child: Column(
        children: [
          Icon(Icons.search_off_rounded, size: 34, color: AppColors.inkMuted),
          const SizedBox(height: 10),
          Text(
            'Tidak ada doa yang cocok',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Coba kata lain, mis. makan, tidur atau masjid.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.inkMuted,
            ),
          ),
        ],
      ),
    );
  }
}
