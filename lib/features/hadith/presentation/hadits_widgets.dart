import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muslimku/core/storage/content_cache.dart';
import 'package:muslimku/core/theme/app_colors.dart';
import 'package:muslimku/features/hadith/domain/hadith_model.dart';
import 'package:muslimku/features/hadith/presentation/hadits_detail_screen.dart';
import 'package:muslimku/features/hadith/presentation/hadits_format.dart';
import 'package:muslimku/shared/application/favorites_provider.dart';
import 'package:muslimku/shared/widgets/senja/senja.dart';

/// Opens the detail page of hadith [number] of [book].
Future<void> openHaditsDetail(
  BuildContext context,
  HaditsBook book,
  int number,
) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => HaditsDetailScreen(book: book, number: number),
    ),
  );
}

/// Bookmark toggle of one hadith, saved in `favoritesProvider('hadits')`.
class HaditsBookmarkButton extends ConsumerWidget {
  const HaditsBookmarkButton({
    super.key,
    required this.favoriteKey,
    this.iconSize = 22,
    this.idleColor,
  });

  /// `arbain:16`, `bm:12`, `bukhari:52`.
  final String favoriteKey;
  final double iconSize;

  /// Defaults to `AppColors.inkMuted`.
  final Color? idleColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final marked = ref.watch(favoritesProvider('hadits')).contains(favoriteKey);
    return Semantics(
      toggled: marked,
      child: SenjaIconButton(
        icon: marked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
        tooltip: marked ? 'Hapus tanda' : 'Tandai hadits',
        color: marked ? AppColors.secondary : idleColor ?? AppColors.inkMuted,
        iconSize: iconSize,
        onPressed: () =>
            ref.read(favoritesProvider('hadits').notifier).toggle(favoriteKey),
      ),
    );
  }
}

/// List row of the Hadits tab (design `.row.hr`): star badge, a title of up
/// to two lines, an optional subtitle and a bookmark at the right edge.
///
/// The row spans the full width and carries the 20 px side padding itself, so
/// the bookmark keeps a 40 px target while its icon sits where the design
/// puts it and the title keeps the design's width.
class HaditsListRow extends StatelessWidget {
  const HaditsListRow({
    super.key,
    required this.number,
    required this.title,
    required this.favoriteKey,
    required this.onTap,
    this.subtitle,
    this.titleStyle,
  });

  static TextStyle get defaultTitleStyle => TextStyle(
    fontSize: 15.5,
    height: 1.3,
    letterSpacing: -0.1,
    fontWeight: FontWeight.w800,
    color: AppColors.ink,
  );

  final int number;
  final String title;
  final String? subtitle;
  final String favoriteKey;
  final VoidCallback onTap;

  /// Defaults to [defaultTitleStyle].
  final TextStyle? titleStyle;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.lilacLine)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: OctagramBadge('$number'),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: titleStyle ?? defaultTitleStyle,
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 3),
                          Text(
                            subtitle!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.inkMuted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 34),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: 11,
          right: 10,
          child: HaditsBookmarkButton(favoriteKey: favoriteKey, iconSize: 21),
        ),
      ],
    );
  }
}

/// "Sedang offline" banner, shown while MyQuran cannot be reached or when
/// [offline] data from the phone is on screen.
class HaditsOfflineNotice extends ConsumerWidget {
  const HaditsOfflineNotice({
    super.key,
    required this.offline,
    this.savedAt,
    this.onRetry,
    this.message = 'Menampilkan hadits yang tersimpan di HP.',
    this.bottom = 14,
  });

  final bool offline;
  final DateTime? savedAt;
  final VoidCallback? onRetry;
  final String message;
  final double bottom;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!offline && !ref.watch(networkStatusProvider)) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: OfflineBanner(
        message: message,
        savedAt: savedAt,
        onRetry: onRetry,
      ),
    );
  }
}

/// "Lompat ke hadits" card (design h3): an optional [selector], a number
/// field for 1–[total] and a purple "Buka" button.
class HaditsJumpCard extends StatefulWidget {
  const HaditsJumpCard({
    super.key,
    required this.total,
    required this.onOpen,
    this.selector,
  });

  final int total;
  final ValueChanged<int> onOpen;
  final Widget? selector;

  @override
  State<HaditsJumpCard> createState() => _HaditsJumpCardState();
}

class _HaditsJumpCardState extends State<HaditsJumpCard> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void didUpdateWidget(HaditsJumpCard old) {
    super.didUpdateWidget(old);
    if (old.total != widget.total && _error != null) _error = null;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _open() {
    final number = int.tryParse(_controller.text.trim());
    final range = '1–${formatRibuan(widget.total)}';
    if (number == null || number < 1 || number > widget.total) {
      setState(() {
        _error = _controller.text.trim().isEmpty
            ? 'Tulis nomor hadits dulu ($range).'
            : 'Nomor $number tidak ada. Pilih $range.';
      });
      return;
    }
    setState(() => _error = null);
    FocusScope.of(context).unfocus();
    widget.onOpen(number);
  }

  @override
  Widget build(BuildContext context) {
    final field = _NumberField(
      controller: _controller,
      hint: 'Nomor 1–${formatRibuan(widget.total)}',
      onSubmitted: _open,
    );
    final button = _OpenButton(onTap: _open);
    // At large text sizes the perawi selector gets its own line.
    final stacked =
        widget.selector != null &&
        MediaQuery.textScalerOf(context).scale(10) > 11.5;
    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        decoration: BoxDecoration(
          color: AppColors.stageBackground,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.lilacLine, width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Lompat ke hadits',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 8),
            if (stacked) ...[
              Align(alignment: Alignment.centerLeft, child: widget.selector),
              const SizedBox(height: 8),
            ],
            Row(
              children: [
                if (widget.selector != null && !stacked) ...[
                  widget.selector!,
                  const SizedBox(width: 8),
                ],
                Expanded(child: field),
                const SizedBox(width: 8),
                button,
              ],
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8, left: 2),
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.offlineAccent,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.controller,
    required this.hint,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final String hint;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: color, width: 1.5),
    );
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.go,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(5),
      ],
      onSubmitted: (_) => onSubmitted(),
      cursorColor: AppColors.secondary,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: AppColors.ink,
      ),
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: Colors.white,
        hintText: hint,
        hintMaxLines: 1,
        hintStyle: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.inkMuted,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 13,
        ),
        enabledBorder: border(AppColors.lilacLine),
        focusedBorder: border(AppColors.secondary),
        border: border(AppColors.lilacLine),
      ),
    );
  }
}

class _OpenButton extends StatelessWidget {
  const _OpenButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      button: true,
      label: 'Buka hadits',
      excludeSemantics: true,
      child: Material(
        color: AppColors.secondary,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 44, minWidth: 64),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            alignment: Alignment.center,
            child: const Text(
              'Buka',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
