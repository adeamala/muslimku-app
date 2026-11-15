import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muslimku/core/theme/app_colors.dart';
import 'package:muslimku/features/hadith/application/hadits_bulughul_provider.dart';
import 'package:muslimku/features/hadith/domain/hadith_model.dart';
import 'package:muslimku/features/hadith/presentation/hadits_format.dart';
import 'package:muslimku/features/hadith/presentation/hadits_widgets.dart';
import 'package:muslimku/shared/widgets/senja/senja.dart';

/// Bulughul Maram: "Lompat ke hadits" and the hadiths in order, loaded page
/// by page while scrolling (MyQuran has one request per hadith).
class BulughulTab extends ConsumerWidget {
  const BulughulTab({super.key});

  static const _book = HaditsBook.bulughulMaram;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(bulughulListProvider);
    final notifier = ref.read(bulughulListProvider.notifier);
    final items = state.items;
    // Rows carry their own side padding (see HaditsListRow).
    return ListView.builder(
      padding: const EdgeInsets.only(top: 14, bottom: 24),
      itemCount: items.length + 2,
      itemBuilder: (context, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                HaditsOfflineNotice(
                  offline: state.offline,
                  onRetry: state.error == null ? null : notifier.loadMore,
                ),
                HaditsJumpCard(
                  total: _book.total,
                  onOpen: (number) => openHaditsDetail(context, _book, number),
                ),
                const SizedBox(height: 18),
                SenjaSectionTitle(
                  'Daftar hadits',
                  trailing: '${formatRibuan(_book.total)} hadits',
                ),
                const SizedBox(height: 4),
              ],
            ),
          );
        }
        if (i <= items.length) return _BulughulRow(entry: items[i - 1]);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _ListEnd(
            // A new key per page: building it asks for the next page.
            key: ValueKey(state.nextNumber),
            state: state,
            onLoadMore: notifier.loadMore,
          ),
        );
      },
    );
  }
}

class _BulughulRow extends StatelessWidget {
  const _BulughulRow({required this.entry});

  final HaditsEntry entry;

  static TextStyle get _style => TextStyle(
    fontSize: 14,
    height: 1.45,
    fontWeight: FontWeight.w600,
    color: AppColors.ink,
  );

  @override
  Widget build(BuildContext context) {
    return HaditsListRow(
      number: entry.number,
      title: entry.excerpt,
      titleStyle: _style,
      favoriteKey: entry.favoriteKey,
      onTap: () => openHaditsDetail(context, entry.book, entry.number),
    );
  }
}

/// Bottom of the list: asks for the next page when it comes into view,
/// offers "Coba lagi" after a failure, and says when everything is shown.
class _ListEnd extends StatefulWidget {
  const _ListEnd({super.key, required this.state, required this.onLoadMore});

  final BulughulListState state;
  final Future<void> Function() onLoadMore;

  @override
  State<_ListEnd> createState() => _ListEndState();
}

class _ListEndState extends State<_ListEnd> {
  @override
  void initState() {
    super.initState();
    _askForMore();
  }

  @override
  void didUpdateWidget(_ListEnd old) {
    super.didUpdateWidget(old);
    if (old.state.loading && !widget.state.loading) _askForMore();
  }

  void _askForMore() {
    final s = widget.state;
    if (s.loading || s.error != null || !s.hasMore) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onLoadMore();
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final style = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: AppColors.inkMuted,
    );
    if (s.error != null) {
      return Padding(
        padding: const EdgeInsets.only(top: 14),
        child: Row(
          children: [
            Expanded(
              child: Text(
                s.items.isEmpty
                    ? 'Hadits belum bisa dimuat. Periksa koneksi internet.'
                    : 'Hadits berikutnya belum bisa dimuat.',
                style: style,
              ),
            ),
            const SizedBox(width: 10),
            SenjaPill(
              label: 'Coba lagi',
              icon: Icons.refresh_rounded,
              lime: true,
              onTap: widget.onLoadMore,
            ),
          ],
        ),
      );
    }
    if (!s.hasMore) {
      return Padding(
        padding: const EdgeInsets.only(top: 18),
        child: Text(
          'Semua ${formatRibuan(HaditsBook.bulughulMaram.total)} hadits sudah tampil.',
          textAlign: TextAlign.center,
          style: style,
        ),
      );
    }
    if (s.items.isEmpty) return const SenjaSkeletonList(rows: 5);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Center(
        child: MediaQuery.disableAnimationsOf(context)
            ? Text('Memuat…', style: style)
            : const SizedBox.square(
                dimension: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppColors.secondary,
                  semanticsLabel: 'Memuat hadits berikutnya',
                ),
              ),
      ),
    );
  }
}
