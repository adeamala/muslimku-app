import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muslimku/core/theme/app_colors.dart';
import 'package:muslimku/features/doa/application/doa_provider.dart';
import 'package:muslimku/features/doa/presentation/doa_widgets.dart';
import 'package:muslimku/features/reading/application/reading_settings_provider.dart';
import 'package:muslimku/shared/application/favorites_provider.dart';
import 'package:muslimku/shared/widgets/senja/senja.dart';

/// One doa (design-v2 d2). [doas] is the list it was opened from (a category,
/// search results or the favourites); the bottom bar walks through it.
class DoaDetailScreen extends ConsumerStatefulWidget {
  const DoaDetailScreen({super.key, required this.doas, required this.index});

  final List<Doa> doas;
  final int index;

  @override
  ConsumerState<DoaDetailScreen> createState() => _DoaDetailScreenState();
}

class _DoaDetailScreenState extends ConsumerState<DoaDetailScreen> {
  late int _index = widget.index.clamp(0, widget.doas.length - 1);
  final _scroll = ScrollController();
  late final ScreenWake _wake;

  @override
  void initState() {
    super.initState();
    _wake = ref.read(screenWakeProvider);
    // "Layar tetap menyala" only holds while this page is open.
    ref.listenManual<bool>(doaKeepAwakeProvider, (previous, on) {
      if (on) {
        _wake.enable();
      } else if (previous == true) {
        _wake.disable();
      }
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    _wake.disable();
    _scroll.dispose();
    super.dispose();
  }

  void _go(int index) {
    setState(() => _index = index);
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  @override
  Widget build(BuildContext context) {
    final doa = widget.doas[_index];
    final all = ref.watch(doaListProvider).valueOrNull?.data ?? widget.doas;
    final inCategory = all.where((d) => d.category == doa.category).length;
    final favourite = ref.watch(favoritesProvider('doa')).contains(doa.key);
    final arabicSize = ref.watch(
      readingSettingsProvider.select((s) => s.arabicSize),
    );
    final hasPrevious = _index > 0;
    final hasNext = _index < widget.doas.length - 1;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Column(
        children: [
          SenjaDetailAppBar(
            title: 'Doa ${doa.categoryLabel}',
            subtitle: '$inCategory doa',
            actions: [
              DoaStarButton(
                favourite: favourite,
                soft: true,
                onPressed: () =>
                    ref.read(favoritesProvider('doa').notifier).toggle(doa.key),
              ),
              SenjaIconButton(
                icon: Icons.ios_share_rounded,
                tooltip: 'Bagikan doa',
                onPressed: () => shareDoa(doa),
              ),
            ],
          ),
          Expanded(
            child: SingleChildScrollView(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SenjaTag(doa.categoryLabel),
                  const SizedBox(height: 10),
                  Semantics(
                    header: true,
                    child: Text(
                      doa.title,
                      style: TextStyle(
                        fontSize: 25,
                        height: 1.24,
                        letterSpacing: -0.4,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ArabicCard(
                    text: doa.arabic,
                    size: arabicSize + 3,
                    align: TextAlign.center,
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'ARTINYA',
                    style: TextStyle(
                      fontSize: 11.5,
                      letterSpacing: 1.1,
                      fontWeight: FontWeight.w800,
                      color: AppColors.secondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    doa.meaning,
                    style: TextStyle(
                      fontSize: 16.5,
                      height: 1.65,
                      fontWeight: FontWeight.w500,
                      color: AppColors.bodyText,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      _FontSizeControl(size: arabicSize),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          'Ukuran huruf',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.inkMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _KeepAwakeRow(
                    value: ref.watch(doaKeepAwakeProvider),
                    onChanged: ref.read(doaKeepAwakeProvider.notifier).set,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: widget.doas.length < 2
          ? null
          : SenjaFloatingBar(
              child: Row(
                children: [
                  Expanded(
                    child: hasPrevious
                        ? DoaStepButton(
                            caption: 'Sebelumnya',
                            label: widget.doas[_index - 1].title,
                            onPressed: () => _go(_index - 1),
                          )
                        : const SizedBox.shrink(),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: hasNext
                        ? DoaStepButton(
                            caption: 'Berikutnya',
                            label: widget.doas[_index + 1].title,
                            next: true,
                            onPressed: () => _go(_index + 1),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
    );
  }
}

/// Lilac "A− | A+" pill; changes the Arabic reading size by 2.
class _FontSizeControl extends ConsumerWidget {
  const _FontSizeControl({required this.size});

  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.read(readingSettingsProvider.notifier);
    // Read the size at tap time: two quick taps both count.
    void change(double by) => settings.setArabicSize(
      ref.read(readingSettingsProvider).arabicSize + by,
    );
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: AppColors.lilac,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SizeButton(
            label: 'A−',
            fontSize: 13,
            tooltip: 'Perkecil huruf Arab',
            onTap: size <= ReadingSettings.minArabicSize
                ? null
                : () => change(-2),
          ),
          Container(width: 1.5, height: 20, color: AppColors.lilacShadow),
          _SizeButton(
            label: 'A+',
            fontSize: 17,
            tooltip: 'Perbesar huruf Arab',
            onTap: size >= ReadingSettings.maxArabicSize
                ? null
                : () => change(2),
          ),
        ],
      ),
    );
  }
}

class _SizeButton extends StatelessWidget {
  const _SizeButton({
    required this.label,
    required this.fontSize,
    required this.tooltip,
    required this.onTap,
  });

  final String label;
  final double fontSize;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 42,
          child: Center(
            child: Opacity(
              opacity: onTap == null ? 0.4 : 1,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w800,
                  color: AppColors.secondary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Bordered "Layar tetap menyala" row with a switch (design `.awake`).
class _KeepAwakeRow extends StatelessWidget {
  const _KeepAwakeRow({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(16);
    return MergeSemantics(
      child: Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: AppColors.lilacLine, width: 1.5),
        ),
        child: InkWell(
          borderRadius: radius,
          onTap: () => onChanged(!value),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Row(
              children: [
                const Icon(
                  Icons.smartphone_rounded,
                  size: 19,
                  color: AppColors.secondary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Layar tetap menyala',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SenjaSwitch(value: value, onChanged: onChanged),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
