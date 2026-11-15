import 'package:flutter/material.dart';
import 'package:muslimku/core/theme/app_colors.dart';
import 'package:muslimku/core/theme/app_text_styles.dart';
import 'package:muslimku/features/asmaul_husna/domain/asmaul_husna_model.dart';
import 'package:muslimku/features/doa/domain/doa_model.dart';
import 'package:muslimku/features/hadith/domain/hadith_model.dart';
import 'package:muslimku/features/quran/domain/quran_ayah_model.dart';
import 'package:share_plus/share_plus.dart';

const _cardRadius = 22.0;

TextStyle _arabic(double size, Color color, {double height = 2.0}) => TextStyle(
  fontFamily: AppTextStyles.arabicFontFamily,
  fontSize: size,
  height: height,
  color: color,
);

const _label = TextStyle(
  fontSize: 11.5,
  fontWeight: FontWeight.w700,
  letterSpacing: 0.5,
  color: AppColors.secondary,
);

/// White card with the lilac outline and flat bottom shadow of the design.
class _OutlinedCard extends StatelessWidget {
  const _OutlinedCard({required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(_cardRadius);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(color: AppColors.lilacLine, offset: const Offset(0, 5)),
        ],
      ),
      child: Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: AppColors.lilacLine, width: 1.5),
        ),
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Padding(padding: const EdgeInsets.all(16), child: child),
        ),
      ),
    );
  }
}

String ayahReference(QuranAyahModel ayah) =>
    'QS. ${ayah.surat.namaLatin} : ${ayah.nomor}';

/// Purple card with a verse, its meaning and a share button.
class AyahCard extends StatelessWidget {
  const AyahCard({super.key, required this.ayah});

  final QuranAyahModel ayah;

  @override
  Widget build(BuildContext context) {
    final reference = ayahReference(ayah);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.ayahDeep, AppColors.secondary],
          stops: [0, 0.7],
        ),
        boxShadow: [
          BoxShadow(color: AppColors.lilacShadow, offset: const Offset(0, 10)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            right: -30,
            top: -30,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.16),
                  width: 18,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'AYAT PILIHAN',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    ayah.arab,
                    textAlign: TextAlign.right,
                    textDirection: TextDirection.rtl,
                    style: _arabic(26, Colors.white),
                  ),
                ),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    ayah.indo,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.6,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        reference,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.white.withValues(alpha: 0.78),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Bagikan ayat',
                      color: Colors.white,
                      icon: const Icon(Icons.share_rounded, size: 20),
                      onPressed: () => SharePlus.instance.share(
                        ShareParams(
                          text:
                              '${ayah.arab}\n\n"${ayah.indo}"\n($reference)\n\nDibagikan dari aplikasi Muslimku',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One hadith at a time, with chips to switch between the three collections.
class HadithCard extends StatefulWidget {
  const HadithCard({super.key, this.arbain, this.bulughul, this.perawi});

  final HadithArbainModel? arbain;
  final HadithModel? bulughul;
  final HadithModel? perawi;

  @override
  State<HadithCard> createState() => _HadithCardState();
}

class _HadithEntry {
  const _HadithEntry(this.chip, this.title, this.arab, this.indo, this.source);

  final String chip;
  final String? title;
  final String arab;
  final String indo;
  final String source;
}

class _HadithCardState extends State<HadithCard> {
  int _selected = 0;
  bool _expanded = false;

  List<_HadithEntry> get _entries => [
    if (widget.arbain != null)
      _HadithEntry(
        'Arbain',
        widget.arbain!.judul.isEmpty ? null : widget.arbain!.judul,
        widget.arbain!.arab,
        widget.arbain!.indo,
        widget.arbain!.nomor > 0
            ? 'Hadits Arbain ke-${widget.arbain!.nomor}'
            : 'Hadits Arbain',
      ),
    if (widget.bulughul != null)
      _HadithEntry(
        'Bulughul Maram',
        null,
        widget.bulughul!.arab,
        widget.bulughul!.indo,
        widget.bulughul!.nomor > 0
            ? 'Bulughul Maram no. ${widget.bulughul!.nomor}'
            : 'Bulughul Maram',
      ),
    if (widget.perawi != null)
      _HadithEntry(
        '9 Perawi',
        null,
        widget.perawi!.arab,
        widget.perawi!.indo,
        widget.perawi!.nomor > 0
            ? 'Hadits 9 Perawi no. ${widget.perawi!.nomor}'
            : 'Hadits 9 Perawi',
      ),
  ];

  @override
  Widget build(BuildContext context) {
    final entries = _entries;
    if (entries.isEmpty) return const SizedBox.shrink();
    final index = _selected.clamp(0, entries.length - 1);
    final e = entries[index];
    return _OutlinedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('HADITS', style: _label),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < entries.length; i++)
                _Chip(
                  label: entries[i].chip,
                  selected: i == index,
                  onTap: () => setState(() {
                    _selected = i;
                    _expanded = false;
                  }),
                ),
            ],
          ),
          if (e.title != null) ...[
            const SizedBox(height: 12),
            Text(
              e.title!,
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w800,
                height: 1.35,
                color: AppColors.ink,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            e.arab,
            textAlign: TextAlign.right,
            textDirection: TextDirection.rtl,
            maxLines: _expanded ? null : 3,
            overflow: _expanded ? null : TextOverflow.ellipsis,
            style: _arabic(20, AppColors.ink, height: 1.9),
          ),
          const SizedBox(height: 6),
          Text(
            e.indo,
            maxLines: _expanded ? null : 4,
            overflow: _expanded ? null : TextOverflow.ellipsis,
            style: TextStyle(fontSize: 14, height: 1.6, color: AppColors.ink),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  e.source,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.inkMuted,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => setState(() => _expanded = !_expanded),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.secondary,
                  textStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: Text(_expanded ? 'Tutup' : 'Selengkapnya'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? AppColors.secondary : AppColors.lilac,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : AppColors.ink,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class DoaCard extends StatelessWidget {
  const DoaCard({super.key, required this.doa});

  final DoaModel doa;

  @override
  Widget build(BuildContext context) {
    return _OutlinedCard(
      onTap: () => showDoaSheet(context, doa),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('DOA', style: _label),
          const SizedBox(height: 6),
          Text(
            doa.judul,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              height: 1.35,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            doa.arab,
            textAlign: TextAlign.right,
            textDirection: TextDirection.rtl,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: _arabic(19, AppColors.ink, height: 1.9),
          ),
          const SizedBox(height: 2),
          const Text(
            'Baca doa',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: AppColors.secondary,
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> showDoaSheet(BuildContext context, DoaModel doa) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppColors.surface,
    builder: (context) => ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.8,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              doa.judul,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              doa.arab,
              textAlign: TextAlign.right,
              textDirection: TextDirection.rtl,
              style: _arabic(26, AppColors.ink),
            ),
            const SizedBox(height: 12),
            Text(
              doa.indo,
              style: TextStyle(fontSize: 15, height: 1.6, color: AppColors.ink),
            ),
          ],
        ),
      ),
    ),
  );
}

class HusnaCard extends StatelessWidget {
  const HusnaCard({super.key, required this.husna});

  final AsmaulHusnaModel husna;

  @override
  Widget build(BuildContext context) {
    return _OutlinedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('ASMAUL HUSNA', style: _label),
          const SizedBox(height: 4),
          Text(
            husna.arab,
            textAlign: TextAlign.center,
            textDirection: TextDirection.rtl,
            style: _arabic(32, AppColors.secondary, height: 1.7),
          ),
          Text(
            husna.latin,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            husna.indo,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.4,
              color: AppColors.inkMuted,
            ),
          ),
        ],
      ),
    );
  }
}

/// Placeholder blocks while the daily content loads.
class DailyCardsSkeleton extends StatelessWidget {
  const DailyCardsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    Widget block(double h, {double radius = 22}) => Container(
      height: h,
      decoration: BoxDecoration(
        color: AppColors.lilac,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
    return Column(
      children: [
        block(220, radius: 26),
        const SizedBox(height: 16),
        block(180),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: block(150)),
            const SizedBox(width: 12),
            Expanded(child: block(150)),
          ],
        ),
      ],
    );
  }
}
