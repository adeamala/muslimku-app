import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muslimku/core/theme/app_colors.dart';
import 'package:muslimku/features/hadith/application/hadits_providers.dart';
import 'package:muslimku/features/hadith/domain/hadith_model.dart';
import 'package:muslimku/features/hadith/presentation/hadits_format.dart';
import 'package:muslimku/features/hadith/presentation/hadits_widgets.dart';
import 'package:muslimku/shared/application/favorites_provider.dart';
import 'package:muslimku/shared/widgets/senja/senja.dart';

/// Arbain An-Nawawi (design h1): "Hadits hari ini", search and the 42 hadiths.
class ArbainTab extends ConsumerStatefulWidget {
  const ArbainTab({super.key});

  @override
  ConsumerState<ArbainTab> createState() => _ArbainTabState();
}

class _ArbainTabState extends ConsumerState<ArbainTab> {
  final _search = TextEditingController();
  String _query = '';
  bool _onlyMarked = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      await ref.read(haditsRepositoryProvider).arbain(refresh: true);
    } catch (_) {
      // Still offline without a saved copy: the error view stays.
    }
    ref.invalidate(arbainListProvider);
    try {
      await ref.read(arbainListProvider.future);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final arbain = ref.watch(arbainListProvider);
    return arbain.when(
      skipLoadingOnRefresh: true,
      loading: () => const _ArbainSkeleton(),
      error: (_, _) => SenjaEmptyState(
        image: 'images/3d/icon_hadits.webp',
        badgeIcon: Icons.wifi_off_rounded,
        title: 'Hadits belum bisa dimuat',
        message:
            'Periksa koneksi internet, lalu coba lagi. Setelah dimuat sekali, '
            'hadits Arbain bisa dibaca tanpa internet.',
        primaryLabel: 'Coba lagi',
        onPrimary: _refresh,
      ),
      data: (cached) {
        final marks = ref.watch(favoritesProvider('hadits'));
        final onlyMarked = _onlyMarked && marks.isNotEmpty;
        final daily = ref.watch(dailyArbainProvider).valueOrNull;
        final rows = [
          for (final entry in cached.data)
            if (matchesArbainQuery(entry, _query) &&
                (!onlyMarked || marks.contains(entry.favoriteKey)))
              entry,
        ];
        final others = onlyMarked
            ? _otherMarks(marks).where(_matchesMark).toList()
            : const <_Mark>[];
        return RefreshIndicator(
          color: AppColors.secondary,
          onRefresh: _refresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                sliver: SliverList.list(
                  children: [
                    HaditsOfflineNotice(
                      offline: cached.offline,
                      savedAt: cached.savedAt,
                      onRetry: _refresh,
                    ),
                    if (daily != null) _DailyCard(entry: daily),
                    const SizedBox(height: 14),
                    SenjaSearchField(
                      hint: 'Cari judul atau nomor hadits',
                      controller: _search,
                      onChanged: (value) => setState(() => _query = value),
                    ),
                    if (marks.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          SenjaChip(
                            label: 'Semua',
                            count: cached.data.length,
                            selected: !onlyMarked,
                            onTap: () => setState(() => _onlyMarked = false),
                          ),
                          const SizedBox(width: 8),
                          SenjaChip(
                            label: 'Ditandai',
                            count: marks.length,
                            icon: Icons.bookmark_rounded,
                            selected: onlyMarked,
                            onTap: () => setState(() => _onlyMarked = true),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 6),
                  ],
                ),
              ),
              // Rows carry their own side padding (see HaditsListRow).
              SliverList.builder(
                itemCount: rows.length + others.length,
                itemBuilder: (context, i) => i < rows.length
                    ? _ArbainRow(entry: rows[i])
                    : _MarkRow(mark: others[i - rows.length]),
              ),
              if (rows.isEmpty && others.isEmpty)
                SliverToBoxAdapter(child: _NoResult(query: _query)),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
        );
      },
    );
  }

  bool _matchesMark(_Mark mark) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return true;
    final digits = RegExp(r'\d+').firstMatch(q)?.group(0);
    return digits != null
        ? '${mark.number}'.startsWith(digits)
        : mark.book.name.toLowerCase().contains(q);
  }

  /// Marked Bulughul Maram and perawi hadiths (`bm:12`, `bukhari:52`), shown
  /// under the marked Arbain ones in "Ditandai".
  List<_Mark> _otherMarks(Set<String> marks) {
    final out = <_Mark>[];
    for (final key in marks) {
      final parts = key.split(':');
      if (parts.length != 2 || parts.first == HaditsBook.arbain.slug) continue;
      final book = HaditsBook.bySlug(parts.first);
      final number = int.tryParse(parts.last);
      if (book != null && number != null) out.add((book: book, number: number));
    }
    final order = [HaditsBook.bulughulMaram, ...HaditsBook.perawi];
    int rank(_Mark m) => order.indexWhere((b) => b.slug == m.book.slug);
    return out..sort(
      (a, b) => rank(a) != rank(b)
          ? rank(a).compareTo(rank(b))
          : a.number.compareTo(b.number),
    );
  }
}

typedef _Mark = ({HaditsBook book, int number});

class _DailyCard extends StatelessWidget {
  const _DailyCard({required this.entry});

  final HaditsEntry entry;

  @override
  Widget build(BuildContext context) {
    void open() => openHaditsDetail(context, entry.book, entry.number);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 132),
      child: SenjaFeatureCard(
        caption: 'Hadits hari ini · No. ${entry.number}',
        title: entry.title,
        titleSize: 19,
        subtitle: entry.excerpt,
        onTap: open,
        trailing: SenjaGoButton(
          icon: Icons.chevron_right_rounded,
          tooltip: 'Baca hadits hari ini',
          size: 44,
          onPressed: open,
        ),
      ),
    );
  }
}

class _ArbainRow extends StatelessWidget {
  const _ArbainRow({required this.entry});

  final HaditsEntry entry;

  @override
  Widget build(BuildContext context) {
    return HaditsListRow(
      number: entry.number,
      title: entry.title,
      subtitle: entry.citation,
      favoriteKey: entry.favoriteKey,
      onTap: () => openHaditsDetail(context, entry.book, entry.number),
    );
  }
}

class _MarkRow extends StatelessWidget {
  const _MarkRow({required this.mark});

  final _Mark mark;

  @override
  Widget build(BuildContext context) {
    return HaditsListRow(
      number: mark.number,
      title: 'Hadits No. ${mark.number}',
      subtitle: mark.book.sourceLabel,
      favoriteKey: '${mark.book.slug}:${mark.number}',
      onTap: () => openHaditsDetail(context, mark.book, mark.number),
    );
  }
}

class _NoResult extends StatelessWidget {
  const _NoResult({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 0),
      child: Text(
        query.trim().isEmpty
            ? 'Belum ada hadits yang ditandai.'
            : 'Tidak ada hadits Arbain untuk "${query.trim()}".',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 13.5,
          height: 1.5,
          fontWeight: FontWeight.w600,
          color: AppColors.inkMuted,
        ),
      ),
    );
  }
}

class _ArbainSkeleton extends StatelessWidget {
  const _ArbainSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      children: [
        Container(
          height: 132,
          decoration: BoxDecoration(
            color: AppColors.lilac,
            borderRadius: BorderRadius.circular(24),
          ),
        ),
        const SizedBox(height: 14),
        Container(
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.lilac,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        const SizedBox(height: 6),
        const SenjaSkeletonList(rows: 5),
      ],
    );
  }
}
