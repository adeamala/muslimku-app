import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muslimku/core/theme/app_colors.dart';
import 'package:muslimku/core/theme/app_text_styles.dart';
import 'package:muslimku/core/utils/arabic_text.dart';
import 'package:muslimku/features/quran/data/mushaf_repository.dart';
import 'package:muslimku/features/quran/data/quran_repository.dart';
import 'package:muslimku/features/quran/domain/quran_models.dart';
import 'package:muslimku/features/quran/presentation/quran_list_shared.dart';
import 'package:muslimku/features/reading/application/reading_settings_provider.dart';
import 'package:muslimku/shared/widgets/senja/senja.dart';

/// Mushaf by page: the 604 pages as continuous Arabic text with ayah
/// markers, swiped in book order (the next page is on the left). Tapping an
/// ayah opens a small sheet to jump into the reader.
class MushafPageScreen extends ConsumerStatefulWidget {
  const MushafPageScreen({super.key, required this.initialPage});

  final int initialPage;

  @override
  ConsumerState<MushafPageScreen> createState() => _MushafPageScreenState();
}

class _MushafPageScreenState extends ConsumerState<MushafPageScreen> {
  late final PageController _controller = PageController(
    initialPage: widget.initialPage - 1,
  );
  late int _page = widget.initialPage;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = ReadingPalette.of(ref.watch(activeReadingThemeProvider));
    final size = ref.watch(readingSettingsProvider).arabicSize;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value:
          (palette.isDark
                  ? SystemUiOverlayStyle.light
                  : SystemUiOverlayStyle.dark)
              .copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: palette.background,
        body: Column(
          children: [
            SenjaDetailAppBar(
              title: 'Halaman $_page',
              subtitle:
                  'dari ${MushafRepository.totalPages} · geser ke kanan '
                  'untuk lanjut',
              foreground: palette.title,
              subtitleColor: palette.muted,
              background: palette.background,
              dark: palette.isDark,
              actions: [
                SenjaIconButton(
                  icon: Icons.format_list_numbered_rounded,
                  tooltip: 'Lompat ke halaman',
                  style: palette.isDark
                      ? SenjaIconStyle.goldOutline
                      : SenjaIconStyle.lilac,
                  onPressed: _jump,
                ),
              ],
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                // Book order: page n+1 lies to the left of page n.
                reverse: true,
                itemCount: MushafRepository.totalPages,
                onPageChanged: (i) => setState(() => _page = i + 1),
                itemBuilder: (context, i) => _MushafPage(
                  page: i + 1,
                  palette: palette,
                  arabicSize: size,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _jump() async {
    final controller = TextEditingController();
    final page = await showSenjaSheet<int>(
      context,
      title: 'Lompat ke halaman',
      builder: (context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SenjaSearchField(
            hint: '1 – ${MushafRepository.totalPages}',
            controller: controller,
            keyboardType: TextInputType.number,
            onSubmitted: (v) => Navigator.pop(context, int.tryParse(v.trim())),
          ),
          const SizedBox(height: 12),
          SenjaButton(
            label: 'Buka',
            height: 48,
            onPressed: () =>
                Navigator.pop(context, int.tryParse(controller.text.trim())),
          ),
        ],
      ),
    );
    controller.dispose();
    if (page == null || page < 1 || page > MushafRepository.totalPages) return;
    if (!mounted) return;
    _controller.jumpToPage(page - 1);
  }
}

class _MushafPage extends ConsumerStatefulWidget {
  const _MushafPage({
    required this.page,
    required this.palette,
    required this.arabicSize,
  });

  final int page;
  final ReadingPalette palette;
  final double arabicSize;

  @override
  ConsumerState<_MushafPage> createState() => _MushafPageState();
}

class _MushafPageState extends ConsumerState<_MushafPage> {
  final _recognizers = <TapGestureRecognizer>[];

  @override
  void dispose() {
    for (final r in _recognizers) {
      r.dispose();
    }
    super.dispose();
  }

  Future<void> _onAyah(Ayah ayah, String surahName) async {
    final open = await showSenjaSheet<bool>(
      context,
      title: '$surahName · ${ayah.number}',
      builder: (context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            ayah.translation,
            style: TextStyle(
              fontSize: 14,
              height: 1.55,
              fontWeight: FontWeight.w500,
              color: AppColors.bodyText,
            ),
          ),
          const SizedBox(height: 14),
          SenjaButton(
            label: 'Buka di halaman baca',
            icon: Icons.menu_book_rounded,
            height: 48,
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );
    if (open == true && mounted) {
      await openQuranReader(context, ayah.surah, ayah: ayah.number);
    }
  }

  @override
  Widget build(BuildContext context) {
    final page = ref.watch(mushafPageProvider(widget.page));
    final surahs = ref.watch(surahListProvider).valueOrNull?.data;
    final palette = widget.palette;
    Surah? surahOf(int n) => surahs?.where((s) => s.number == n).firstOrNull;
    String nameOf(int n) => surahOf(n)?.name ?? 'Surat $n';
    final bottom = MediaQuery.paddingOf(context).bottom;
    return page.when(
      skipLoadingOnRefresh: false,
      data: (data) {
        final ayat = data.data;
        for (final r in _recognizers) {
          r.dispose();
        }
        _recognizers.clear();
        final surahNumbers = {for (final a in ayat) a.surah}.toList()..sort();
        final header =
            '${surahNumbers.map(nameOf).join(' · ')} · Juz ${ayat.first.juz}';
        final blocks = <Widget>[];
        var spans = <InlineSpan>[];
        void flush() {
          if (spans.isEmpty) return;
          blocks.add(
            Text.rich(
              TextSpan(children: spans),
              textAlign: TextAlign.justify,
              textDirection: TextDirection.rtl,
              style: TextStyle(
                fontFamily: AppTextStyles.arabicFontFamily,
                fontSize: widget.arabicSize,
                height: 2.0,
                color: palette.arabic,
              ),
            ),
          );
          spans = [];
        }

        for (final a in ayat) {
          if (a.number == 1) {
            flush();
            final surah = surahOf(a.surah);
            blocks.add(
              _SurahBanner(
                name: nameOf(a.surah),
                arabicName: surah?.arabicName,
                palette: palette,
              ),
            );
            if (surah?.showsBismillah ?? a.surah != 1 && a.surah != 9) {
              blocks.add(
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: ArabicText(
                    bismillah,
                    size: widget.arabicSize * 0.95,
                    align: TextAlign.center,
                    color: palette.arabic,
                  ),
                ),
              );
            }
          }
          final recognizer = TapGestureRecognizer()
            ..onTap = () => _onAyah(a, nameOf(a.surah));
          _recognizers.add(recognizer);
          spans.add(
            TextSpan(
              text: '${a.arab} ',
              recognizer: recognizer,
              semanticsLabel: '${nameOf(a.surah)} ayat ${a.number}',
            ),
          );
          spans.add(
            TextSpan(
              text: '﴿${arabicIndic(a.number)}﴾ ',
              recognizer: recognizer,
              style: TextStyle(
                fontSize: widget.arabicSize * 0.8,
                color: palette.accent,
              ),
            ),
          );
        }
        flush();
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, 4, 20, bottom + 28),
          child: Column(
            key: ValueKey('mushaf-page-${widget.page}'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                header,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: palette.muted,
                ),
              ),
              const SizedBox(height: 10),
              ...blocks,
              const SizedBox(height: 10),
              Text(
                '${widget.page}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: palette.muted,
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 20),
        child: SenjaSkeletonList(rows: 8),
      ),
      error: (_, _) => SenjaEmptyState(
        image: 'images/3d/icon_quran.webp',
        badgeIcon: Icons.wifi_off_rounded,
        title: 'Halaman ${widget.page} belum tersimpan',
        message:
            'Halaman diunduh saat dibuka dengan internet, atau diambil '
            'dari surat yang sudah tersimpan di HP.',
        primaryLabel: 'Coba lagi',
        onPrimary: () => ref.invalidate(mushafPageProvider(widget.page)),
      ),
    );
  }
}

class _SurahBanner extends StatelessWidget {
  const _SurahBanner({
    required this.name,
    required this.arabicName,
    required this.palette,
  });

  final String name;
  final String? arabicName;
  final ReadingPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.line),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              name,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: palette.title,
              ),
            ),
          ),
          if (arabicName != null)
            Text(
              arabicName!,
              textDirection: TextDirection.rtl,
              style: TextStyle(
                fontFamily: AppTextStyles.arabicFontFamily,
                fontSize: 20,
                color: palette.accent,
              ),
            ),
        ],
      ),
    );
  }
}
