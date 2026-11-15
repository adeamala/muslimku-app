import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:muslimku/core/theme/app_colors.dart';
import 'package:muslimku/features/quran/domain/quran_models.dart';
import 'package:muslimku/shared/widgets/senja/senja.dart';

/// Short introduction of the surah from MyQuran (`tafsir`).
Future<void> showTafsirSheet(BuildContext context, Surah surah) {
  final text = surah.tafsir.replaceAll(RegExp(r'[ \t]{2,}'), ' ').trim();
  return showSenjaSheet<void>(
    context,
    title: 'Tafsir ${surah.name}',
    builder: (_) => Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        text.isEmpty ? 'Tafsir surat ini belum tersedia.' : text,
        style: TextStyle(
          fontSize: 14.5,
          height: 1.65,
          fontWeight: FontWeight.w500,
          color: AppColors.bodyText,
        ),
      ),
    ),
  );
}

/// "Lompat ke ayat": asks for an ayah number from 1 to [count].
Future<int?> showJumpToAyahSheet(BuildContext context, {required int count}) {
  return showSenjaSheet<int>(
    context,
    title: 'Lompat ke ayat',
    builder: (_) => _JumpPanel(count: count),
  );
}

class _JumpPanel extends StatefulWidget {
  const _JumpPanel({required this.count});

  final int count;

  @override
  State<_JumpPanel> createState() => _JumpPanelState();
}

class _JumpPanelState extends State<_JumpPanel> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit([String? _]) {
    final n = int.tryParse(_controller.text.trim());
    if (n == null || n < 1 || n > widget.count) {
      setState(() => _error = 'Pilih nomor 1–${widget.count}');
      return;
    }
    Navigator.pop(context, n);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                alignment: Alignment.centerLeft,
                decoration: BoxDecoration(
                  color: AppColors.lilac,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: TextField(
                  controller: _controller,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.go,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onSubmitted: _submit,
                  cursorColor: AppColors.secondary,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                  decoration: InputDecoration.collapsed(
                    hintText: 'Nomor ayat 1–${widget.count}',
                    hintStyle: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.inkMuted,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 92,
              child: SenjaButton(label: 'Buka', height: 48, onPressed: _submit),
            ),
          ],
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 4),
            child: Text(
              _error!,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AppColors.offlineAccent,
              ),
            ),
          ),
      ],
    );
  }
}

enum AyahMoreAction { tafsir, copy, markLastRead }

/// More actions for one ayah.
Future<AyahMoreAction?> showAyahMoreSheet(
  BuildContext context, {
  required int ayah,
}) {
  return showSenjaSheet<AyahMoreAction>(
    context,
    title: 'Ayat $ayah',
    builder: (context) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SheetRow(
          icon: Icons.menu_book_rounded,
          label: 'Tafsir ayat',
          onTap: () => Navigator.pop(context, AyahMoreAction.tafsir),
        ),
        _SheetRow(
          icon: Icons.copy_rounded,
          label: 'Salin ayat',
          onTap: () => Navigator.pop(context, AyahMoreAction.copy),
        ),
        _SheetRow(
          icon: Icons.bookmark_added_outlined,
          label: 'Tandai terakhir dibaca',
          divider: false,
          onTap: () => Navigator.pop(context, AyahMoreAction.markLastRead),
        ),
      ],
    ),
  );
}

class _SheetRow extends StatelessWidget {
  const _SheetRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.divider = true,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 58),
        decoration: BoxDecoration(
          border: divider
              ? Border(bottom: BorderSide(color: AppColors.lilacLine))
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.lilac,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 19, color: AppColors.secondary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
