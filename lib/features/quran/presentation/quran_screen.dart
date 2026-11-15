import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muslimku/features/quran/data/quran_repository.dart';
import 'package:muslimku/features/quran/presentation/bookmarks_tab.dart';
import 'package:muslimku/features/quran/presentation/juz_tab.dart';
import 'package:muslimku/features/quran/presentation/quran_list_shared.dart';
import 'package:muslimku/features/quran/presentation/surah_tab.dart';
import 'package:muslimku/features/quran/presentation/theme_ayat_screen.dart';
import 'package:muslimku/shared/widgets/senja/senja.dart';

/// Al-Qur'an tab (design-v2 `q1`, `q2`, `o1`): surah list, juz with khatam
/// progress, the thematic index and marked ayat. Each tab keeps its own scroll position and is
/// built on its first visit.
class QuranScreen extends ConsumerStatefulWidget {
  const QuranScreen({super.key});

  @override
  ConsumerState<QuranScreen> createState() => _QuranScreenState();
}

class _QuranScreenState extends ConsumerState<QuranScreen> {
  int _tab = QuranTabs.surat;
  final Set<int> _visited = {QuranTabs.surat};

  void _select(int tab) {
    if (tab == _tab) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _tab = tab;
      _visited.add(tab);
    });
  }

  Widget _view(int tab) => switch (tab) {
    QuranTabs.juz => JuzTab(onTab: _select),
    QuranTabs.tema => ThemesTab(onTab: _select),
    QuranTabs.ditandai => BookmarksTab(onTab: _select),
    _ => SurahTab(onTab: _select),
  };

  @override
  Widget build(BuildContext context) {
    // Keep the saved marks on the rows and the download card in step: the
    // download saves surahs, and so does the reader when a surah is opened.
    ref.listen(quranDownloadProvider.select((s) => s.storedSurahs), (
      previous,
      next,
    ) {
      if (previous != next) ref.invalidate(storedSurahsProvider);
    });
    ref.listen(storedSurahsProvider, (previous, next) {
      final count = next.valueOrNull?.length;
      if (count != null && count != previous?.valueOrNull?.length) {
        ref.read(quranDownloadProvider.notifier).refresh();
      }
    });
    return SenjaTabScaffold(
      title: "Al-Qur'an",
      subtitle: '114 surat · 30 juz',
      hero: 'images/3d/icon_quran.webp',
      heroWidth: 176,
      heroTop: 58,
      heroRight: 10,
      body: Material(
        type: MaterialType.transparency,
        child: QuranTextDefaults(
          child: IndexedStack(
            index: _tab,
            sizing: StackFit.expand,
            children: [
              for (var i = 0; i < QuranTabs.count; i++)
                _visited.contains(i)
                    ? TickerMode(enabled: i == _tab, child: _view(i))
                    : const SizedBox.shrink(),
            ],
          ),
        ),
      ),
    );
  }
}
