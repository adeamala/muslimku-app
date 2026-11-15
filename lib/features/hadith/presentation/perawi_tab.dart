import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muslimku/core/theme/app_colors.dart';
import 'package:muslimku/features/hadith/application/hadits_last_read_provider.dart';
import 'package:muslimku/features/hadith/application/hadits_providers.dart';
import 'package:muslimku/features/hadith/domain/hadith_model.dart';
import 'package:muslimku/features/hadith/presentation/hadits_format.dart';
import 'package:muslimku/features/hadith/presentation/hadits_widgets.dart';
import 'package:muslimku/shared/widgets/senja/senja.dart';

/// 9 Perawi (design h3): "Lompat ke hadits" with a perawi selector and a
/// grid of the nine books. A tile continues at the last number read.
class PerawiTab extends ConsumerStatefulWidget {
  const PerawiTab({super.key});

  @override
  ConsumerState<PerawiTab> createState() => _PerawiTabState();
}

class _PerawiTabState extends ConsumerState<PerawiTab> {
  String _selected = HaditsBook.perawi.first.slug;

  Future<void> _refresh() async {
    await ref.read(haditsRepositoryProvider).perawi(refresh: true);
    ref.invalidate(perawiBooksProvider);
    await ref.read(perawiBooksProvider.future);
  }

  Future<void> _openTile(HaditsBook book) async {
    setState(() => _selected = book.slug);
    final notifier = ref.read(perawiLastNumberProvider.notifier);
    await notifier.ready;
    if (!mounted) return;
    final number = notifier.numberFor(book.slug).clamp(1, book.total);
    await openHaditsDetail(context, book, number);
  }

  Future<void> _pick(List<HaditsBook> books) async {
    final picked = await showSenjaSheet<HaditsBook>(
      context,
      title: 'Pilih perawi',
      builder: (context) => Column(
        children: [
          for (final book in books)
            _PerawiOption(
              book: book,
              selected: book.slug == _selected,
              onTap: () => Navigator.pop(context, book),
            ),
        ],
      ),
    );
    if (picked != null && mounted) setState(() => _selected = picked.slug);
  }

  @override
  Widget build(BuildContext context) {
    final cached = ref.watch(perawiBooksProvider).valueOrNull;
    final books = cached?.data ?? HaditsBook.perawi;
    final book = books.firstWhere(
      (b) => b.slug == _selected,
      orElse: () => books.first,
    );
    final total = books.fold<int>(0, (sum, b) => sum + b.total);
    return RefreshIndicator(
      color: AppColors.secondary,
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        children: [
          HaditsOfflineNotice(
            offline: cached?.offline ?? false,
            savedAt: cached?.savedAt,
            onRetry: _refresh,
          ),
          HaditsJumpCard(
            total: book.total,
            selector: _PerawiSelector(book: book, onTap: () => _pick(books)),
            onOpen: (number) => openHaditsDetail(context, book, number),
          ),
          const SizedBox(height: 18),
          SenjaSectionTitle(
            'Pilih perawi',
            trailing: '${formatRibuan(total)} hadits',
          ),
          const SizedBox(height: 10),
          for (var row = 0; row * 3 < books.length; row++) ...[
            if (row > 0) const SizedBox(height: 10),
            Row(
              children: [
                for (var col = 0; col < 3; col++) ...[
                  if (col > 0) const SizedBox(width: 10),
                  Expanded(
                    child: row * 3 + col < books.length
                        ? _PerawiTile(
                            book: books[row * 3 + col],
                            selected: books[row * 3 + col].slug == book.slug,
                            onTap: () => _openTile(books[row * 3 + col]),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// "Bukhari ⌄" in the jump card.
class _PerawiSelector extends StatelessWidget {
  const _PerawiSelector({required this.book, required this.onTap});

  final HaditsBook book;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      button: true,
      label: 'Perawi ${book.name}, ganti perawi',
      excludeSemantics: true,
      child: Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: AppColors.lilacLine, width: 1.5),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 44, maxWidth: 150),
            padding: const EdgeInsets.only(left: 12, right: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    book.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.secondary,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 20,
                  color: AppColors.secondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PerawiTile extends StatelessWidget {
  const _PerawiTile({
    required this.book,
    required this.selected,
    required this.onTap,
  });

  final HaditsBook book;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      label: '${book.name}, ${formatRibuan(book.total)} hadits',
      excludeSemantics: true,
      child: SizedBox(
        height: 108,
        child: SenjaCard(
          selected: selected,
          onTap: onTap,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ArabicText(
                    book.arabicName,
                    size: 21,
                    height: 1.5,
                    color: AppColors.secondary,
                    align: TextAlign.center,
                  ),
                  const SizedBox(height: 1),
                  Text(
                    book.name,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    '${formatRibuan(book.total)} hadits',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.inkMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A row of the "Pilih perawi" sheet.
class _PerawiOption extends StatelessWidget {
  const _PerawiOption({
    required this.book,
    required this.selected,
    required this.onTap,
  });

  final HaditsBook book;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      child: SenjaListRow(
        padding: const EdgeInsets.symmetric(vertical: 10),
        leading: SizedBox(
          width: 64,
          child: ArabicText(
            book.arabicName,
            size: 19,
            height: 1.4,
            color: AppColors.secondary,
            align: TextAlign.center,
            maxLines: 1,
          ),
        ),
        title: book.name,
        subtitle: '${formatRibuan(book.total)} hadits',
        trailing: selected
            ? const Icon(
                Icons.check_circle_rounded,
                color: AppColors.secondary,
                size: 22,
              )
            : null,
        onTap: onTap,
      ),
    );
  }
}
