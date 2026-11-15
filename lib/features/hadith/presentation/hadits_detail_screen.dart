import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muslimku/core/storage/content_cache.dart';
import 'package:muslimku/core/theme/app_colors.dart';
import 'package:muslimku/features/hadith/application/hadits_last_read_provider.dart';
import 'package:muslimku/features/hadith/application/hadits_providers.dart';
import 'package:muslimku/features/hadith/domain/hadith_model.dart';
import 'package:muslimku/features/hadith/presentation/hadits_detail_parts.dart';
import 'package:muslimku/features/hadith/presentation/hadits_format.dart';
import 'package:muslimku/features/hadith/presentation/hadits_widgets.dart';
import 'package:muslimku/features/reading/application/reading_settings_provider.dart';
import 'package:muslimku/shared/widgets/senja/senja.dart';
import 'package:share_plus/share_plus.dart';

/// One hadith of Arbain, Bulughul Maram or a perawi (design h2), with
/// "‹ No. 15" / "No. 17 ›" to step through the book.
class HaditsDetailScreen extends ConsumerStatefulWidget {
  const HaditsDetailScreen({
    super.key,
    required this.book,
    required this.number,
  });

  final HaditsBook book;
  final int number;

  @override
  ConsumerState<HaditsDetailScreen> createState() => _HaditsDetailScreenState();
}

class _HaditsDetailScreenState extends ConsumerState<HaditsDetailScreen> {
  late int _number = widget.number;
  final _scroll = ScrollController();
  ScaffoldMessengerState? _messenger;

  HaditsBook get _book => widget.book;

  @override
  void initState() {
    super.initState();
    _remember();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _messenger = ScaffoldMessenger.maybeOf(context);
  }

  @override
  void didUpdateWidget(HaditsDetailScreen old) {
    super.didUpdateWidget(old);
    if (old.book != widget.book || old.number != widget.number) {
      _number = widget.number;
      _remember();
    }
  }

  @override
  void dispose() {
    // The app-wide messenger would carry "Hadits disalin" to the tab.
    _messenger?.clearSnackBars();
    _scroll.dispose();
    super.dispose();
  }

  /// A perawi tile continues at the last number read.
  void _remember() {
    if (!_book.isPerawi) return;
    final number = _number;
    Future.microtask(() {
      if (mounted) {
        ref
            .read(perawiLastNumberProvider.notifier)
            .remember(_book.slug, number);
      }
    });
  }

  void _go(int number) {
    setState(() => _number = number);
    _remember();
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _retry() {
    if (_book.isArbain) {
      ref.invalidate(arbainListProvider);
    } else {
      ref.invalidate(haditsEntryProvider((book: _book, number: _number)));
    }
  }

  /// Arbain comes straight from the loaded list, so stepping never flickers.
  AsyncValue<Cached<HaditsEntry>> _arbainEntry() {
    final list = ref.watch(arbainListProvider);
    final value = list.valueOrNull;
    if (value != null) {
      for (final item in value.data) {
        if (item.number == _number) return AsyncData(value.map((_) => item));
      }
      return AsyncError(
        StateError('Arbain No. $_number tidak ada'),
        StackTrace.current,
      );
    }
    if (list.hasError) {
      return AsyncError(list.error!, list.stackTrace ?? StackTrace.current);
    }
    return const AsyncLoading();
  }

  Future<void> _copy(HaditsEntry entry) async {
    await Clipboard.setData(ClipboardData(text: haditsShareText(entry)));
    if (!mounted) return;
    final bottom = MediaQuery.paddingOf(context).bottom;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text(
            'Hadits disalin',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.ink,
          margin: EdgeInsets.fromLTRB(20, 0, 20, 96 + bottom),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
  }

  void _share(HaditsEntry entry) {
    SharePlus.instance.share(ShareParams(text: haditsShareText(entry)));
  }

  @override
  Widget build(BuildContext context) {
    final entry = _book.isArbain
        ? _arbainEntry()
        : ref.watch(haditsEntryProvider((book: _book, number: _number)));
    final total = _book.isArbain
        ? ref.watch(arbainListProvider).valueOrNull?.data.length ?? _book.total
        : _book.total;
    final loaded = entry.valueOrNull?.data;
    final barSpace = 70 + 14 + 24 + MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Stack(
        children: [
          Column(
            children: [
              HaditsDetailAppBar(
                title: '${_book.name} · No. $_number',
                subtitle: 'dari ${formatRibuan(total)} hadits',
                actions: [
                  SenjaIconButton(
                    style: SenjaIconStyle.lilac,
                    tooltip: 'Ukuran huruf Arab',
                    onPressed: () =>
                        showArabicSizeSheet(context, sample: loaded?.arab),
                    child: const Text(
                      'Aa',
                      style: TextStyle(letterSpacing: -0.3),
                    ),
                  ),
                  HaditsBookmarkButton(
                    favoriteKey: '${_book.slug}:$_number',
                    idleColor: AppColors.ink,
                  ),
                ],
              ),
              Expanded(
                child: entry.when(
                  data: (cached) => _DetailBody(
                    cached: cached,
                    controller: _scroll,
                    bottomPadding: barSpace,
                    onRetry: _retry,
                  ),
                  loading: () => const HaditsDetailSkeleton(),
                  error: (_, _) => Padding(
                    padding: EdgeInsets.only(bottom: barSpace - 24),
                    child: SenjaEmptyState(
                      image: 'images/3d/icon_hadits.webp',
                      badgeIcon: Icons.wifi_off_rounded,
                      title: 'Hadits belum bisa dibuka',
                      message:
                          'Periksa koneksi internet, lalu coba lagi. Hadits '
                          'yang pernah dibuka tetap bisa dibaca tanpa internet.',
                      primaryLabel: 'Coba lagi',
                      onPrimary: _retry,
                    ),
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SenjaFloatingBar(
              child: HaditsStepBar(
                number: _number,
                total: total,
                onGo: _go,
                onCopy: loaded == null ? null : () => _copy(loaded),
                onShare: loaded == null ? null : () => _share(loaded),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailBody extends ConsumerWidget {
  const _DetailBody({
    required this.cached,
    required this.controller,
    required this.bottomPadding,
    required this.onRetry,
  });

  final Cached<HaditsEntry> cached;
  final ScrollController controller;
  final double bottomPadding;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entry = cached.data;
    final arabicSize = ref.watch(
      readingSettingsProvider.select((s) => s.arabicSize),
    );
    final title = entry.title.isNotEmpty
        ? entry.title
        : 'Hadits No. ${entry.number}';
    return SingleChildScrollView(
      controller: controller,
      padding: EdgeInsets.fromLTRB(20, 6, 20, bottomPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HaditsOfflineNotice(
            offline: cached.offline,
            savedAt: cached.savedAt,
            onRetry: onRetry,
            message: 'Hadits ini dibuka dari simpanan di HP.',
          ),
          SenjaTag(entry.book.sourceLabel),
          const SizedBox(height: 10),
          Semantics(
            header: true,
            child: Text(
              title,
              style: TextStyle(
                fontSize: 25,
                height: 1.24,
                letterSpacing: -0.4,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
          ),
          if (entry.book.isArbain)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                entry.citation,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.inkMuted,
                ),
              ),
            ),
          const SizedBox(height: 16),
          if (entry.arab.isNotEmpty) ...[
            ArabicCard(text: entry.arab, size: arabicSize * 0.86),
            const SizedBox(height: 18),
          ],
          const Text(
            'TERJEMAHAN',
            style: TextStyle(
              fontSize: 11.5,
              letterSpacing: 1.1,
              fontWeight: FontWeight.w800,
              color: AppColors.secondary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            entry.translation,
            style: TextStyle(
              fontSize: 15,
              height: 1.65,
              fontWeight: FontWeight.w500,
              color: AppColors.bodyText,
            ),
          ),
        ],
      ),
    );
  }
}
