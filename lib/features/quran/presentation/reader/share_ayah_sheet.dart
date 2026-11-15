import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muslimku/core/theme/app_colors.dart';
import 'package:muslimku/features/quran/domain/quran_models.dart';
import 'package:muslimku/features/quran/presentation/reader/reader_controls.dart';
import 'package:muslimku/features/quran/presentation/reader/reader_text.dart';
import 'package:muslimku/features/quran/presentation/reader/share_card.dart';
import 'package:muslimku/shared/widgets/senja/senja.dart';
import 'package:share_plus/share_plus.dart';

/// Hands the PNG and its reference to the system share sheet; tests override
/// it.
final shareAyahImageProvider =
    Provider<Future<void> Function(Uint8List png, String text)>(
      (ref) => _shareWithSystem,
    );

Future<void> _shareWithSystem(Uint8List png, String text) =>
    SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(png, mimeType: 'image/png', name: 'muslimku-ayat.png'),
        ],
        text: text,
      ),
    );

/// "Bagikan ayat" (design q6): the ayah as a 4:5 image in three looks, made
/// on the phone and handed to the system share sheet.
Future<void> showShareAyahSheet(
  BuildContext context, {
  required Surah surah,
  required Ayah ayah,
  ShareTemplate template = ShareTemplate.senja,
}) {
  return showSenjaSheet<void>(
    context,
    title: 'Bagikan ayat',
    titleAction: Builder(
      builder: (context) => SenjaIconButton(
        icon: Icons.close_rounded,
        tooltip: 'Tutup',
        onPressed: () => Navigator.pop(context),
      ),
    ),
    builder: (_) =>
        ShareAyahPanel(surah: surah, ayah: ayah, template: template),
  );
}

class ShareAyahPanel extends ConsumerStatefulWidget {
  const ShareAyahPanel({
    super.key,
    required this.surah,
    required this.ayah,
    this.template = ShareTemplate.senja,
  });

  final Surah surah;
  final Ayah ayah;
  final ShareTemplate template;

  @override
  ConsumerState<ShareAyahPanel> createState() => _ShareAyahPanelState();
}

class _ShareAyahPanelState extends ConsumerState<ShareAyahPanel> {
  final _card = GlobalKey();
  late ShareTemplate _template = widget.template;
  bool _withTranslation = true;
  bool _busy = false;
  String? _error;

  String get _reference => ayahReference(widget.surah, widget.ayah.number);

  Future<void> _copy() async {
    await Clipboard.setData(
      ClipboardData(
        text: ayahShareText(
          widget.surah,
          widget.ayah,
          translation: _withTranslation,
        ),
      ),
    );
    if (!mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    Navigator.pop(context);
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Teks ayat disalin')));
  }

  Future<void> _shareImage() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final boundary =
          _card.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (png == null) throw StateError('The card could not be drawn');
      await ref.read(shareAyahImageProvider)(
        png.buffer.asUint8List(),
        _reference,
      );
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Gambar belum bisa dibagikan. Coba "Salin teks".',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final translation = cleanTranslation(widget.ayah.translation);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Transform.translate(
          offset: const Offset(0, -4),
          child: Text(
            _reference,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.inkMuted,
            ),
          ),
        ),
        const SizedBox(height: 14),
        Center(
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: AppColors.ink.withValues(alpha: 0.3),
                  blurRadius: 36,
                  offset: const Offset(0, 18),
                ),
              ],
            ),
            child: RepaintBoundary(
              key: _card,
              child: AyahShareCard(
                template: _template,
                arabic: widget.ayah.arab,
                reference: _reference,
                translation: _withTranslation ? translation : null,
              ),
            ),
          ),
        ),
        const SizedBox(height: 11),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (final t in ShareTemplate.values)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: ShareTemplateSwatch(
                  template: t,
                  selected: t == _template,
                  onTap: () => setState(() => _template = t),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        ReaderToggleRow(
          label: 'Sertakan terjemahan',
          value: _withTranslation,
          onChanged: (v) => setState(() => _withTranslation = v),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              _error!,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AppColors.offlineAccent,
              ),
            ),
          ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              flex: 4,
              child: _ActionButton(
                label: 'Salin teks',
                icon: Icons.copy_rounded,
                outline: true,
                onPressed: _copy,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 6,
              child: _ActionButton(
                label: _busy ? 'Menyiapkan…' : 'Bagikan gambar',
                icon: Icons.ios_share_rounded,
                onPressed: _busy ? null : _shareImage,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// 52 px button of the share sheet; the label shrinks instead of wrapping.
class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.outline = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool outline;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onPressed == null ? 0.6 : 1,
      child: Material(
        color: outline ? Colors.white : AppColors.primary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: outline
              ? BorderSide(color: AppColors.lilacLine, width: 1.5)
              : BorderSide.none,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onPressed,
          child: SizedBox(
            height: 52,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 18, color: AppColors.ink),
                      const SizedBox(width: 8),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
