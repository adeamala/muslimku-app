import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muslimku/features/quran/application/quran_audio_provider.dart';
import 'package:muslimku/features/quran/application/quran_progress_provider.dart';
import 'package:muslimku/features/quran/application/quran_reader_progress.dart';
import 'package:muslimku/features/quran/data/quran_repository.dart';
import 'package:muslimku/features/quran/data/tajweed_repository.dart';
import 'package:muslimku/features/quran/domain/quran_models.dart';
import 'package:muslimku/features/quran/presentation/mushaf_page_screen.dart';
import 'package:muslimku/features/quran/presentation/reader/ayah_item.dart';
import 'package:muslimku/features/quran/presentation/reader/murottal_bar.dart';
import 'package:muslimku/features/quran/presentation/reader/murottal_sheet.dart';
import 'package:muslimku/features/quran/presentation/reader/reader_chrome.dart';
import 'package:muslimku/features/quran/presentation/reader/reader_scroll.dart';
import 'package:muslimku/features/quran/presentation/reader/reader_sheets.dart';
import 'package:muslimku/features/quran/presentation/reader/reader_states.dart';
import 'package:muslimku/features/quran/presentation/reader/reader_text.dart';
import 'package:muslimku/features/quran/presentation/reader/reading_settings_sheet.dart';
import 'package:muslimku/features/quran/presentation/reader/share_ayah_sheet.dart';
import 'package:muslimku/features/quran/presentation/reader/share_card.dart';
import 'package:muslimku/features/quran/presentation/reader/tafsir_sheet.dart';
import 'package:muslimku/features/reading/application/reading_settings_provider.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

/// Reads one surah (design-v2 screens q3–q6 and o2).
///
/// Opened from the surah list, the juz grid ("Juz 2" opens Al-Baqarah 142),
/// bookmarks and "Lanjutkan membaca". [initialAyah] is scrolled into view.
class QuranReaderScreen extends ConsumerStatefulWidget {
  const QuranReaderScreen({
    super.key,
    required this.surahNumber,
    this.initialAyah = 1,
  });

  final int surahNumber;
  final int initialAyah;

  @override
  ConsumerState<QuranReaderScreen> createState() => _QuranReaderScreenState();
}

class _QuranReaderScreenState extends ConsumerState<QuranReaderScreen> {
  final _scroll = ItemScrollController();
  final _positions = ItemPositionsListener.create();
  late final LastReadNotifier _lastRead = ref.read(lastReadProvider.notifier);
  QuranAudioController? _audio;
  ScaffoldMessengerState? _messenger;
  ReaderProgressTracker? _tracker;
  Surah? _surah;
  List<Ayah> _ayat = const [];
  int? _startIndex;
  bool _night = false;

  /// Topmost ayah below the app bar; drives "Juz 22 · Hal. 440".
  int _first = 1;

  /// How far the surah header has scrolled up (px); the night app bar fades in.
  double _headerScroll = 0;
  double _viewport = 0;
  double _barHeight = 56;

  /// Ayah with the "Terakhir dibaca" tag: where the user stopped last time,
  /// or what they marked now.
  int? _lastReadAyah;

  int get _n => widget.surahNumber;

  @override
  void initState() {
    super.initState();
    _positions.itemPositions.addListener(_onPositions);
    _lastReadAyah = _savedAyahHere();
    _lastRead.ready.then((_) {
      if (!mounted || _lastReadAyah != null || (_tracker?.hasSaved ?? false)) {
        return;
      }
      final ayah = _savedAyahHere();
      if (ayah != null) setState(() => _lastReadAyah = ayah);
    });
  }

  int? _savedAyahHere() {
    final saved = ref.read(lastReadProvider);
    return saved != null && saved.surah == _n ? saved.ayah : null;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _messenger = ScaffoldMessenger.maybeOf(context);
  }

  @override
  void dispose() {
    _positions.itemPositions.removeListener(_onPositions);
    _tracker?.dispose();
    final audio = _audio?..release();
    final messenger = _messenger;
    // Providers must not change while the widget tree is being torn down.
    Future.microtask(() {
      audio?.stop();
      if (messenger != null && messenger.mounted) messenger.clearSnackBars();
    });
    super.dispose();
  }

  /// Saves after the current frame, and only while the app is alive.
  Future<void> _saveLastRead(LastRead value) async {
    await Future<void>.value();
    if (_lastRead.mounted) await _lastRead.save(value);
  }

  void _onPositions() {
    if (!mounted || _surah == null || _ayat.isEmpty || _viewport <= 0) return;
    final positions = _positions.itemPositions.value;
    final view = visibleAyat(
      positions,
      ayahCount: _ayat.length,
      top: _barHeight / _viewport,
    );
    final first = view.first;
    if (first == null) return;
    final ayah = _ayat[first - 1].number;
    final header = positions.where((p) => p.index == 0).firstOrNull;
    final scrolled = header == null
        ? 120.0
        : (-header.itemLeadingEdge * _viewport).clamp(0.0, 120.0);
    if (ayah != _first || (_night && (scrolled - _headerScroll).abs() >= 1)) {
      setState(() {
        _first = ayah;
        _headerScroll = scrolled;
      });
    }
    _tracker?.update(ayah, [for (final i in view.visible) _ayat[i - 1].number]);
  }

  void _onAudio(MurottalState? previous, MurottalState next) {
    final message = next.message;
    if (message != null && message != previous?.message) {
      _toast(message);
      Future.microtask(() => _audio?.clearMessage());
    }
    final ayah = next.ayah;
    if (next.surah == _n && ayah != null && ayah != previous?.ayah) {
      _reveal(ayah);
    }
  }

  /// Scrolls the recited ayah into view when it is (partly) hidden.
  void _reveal(int ayah) {
    if (!mounted || _viewport <= 0) return;
    final index = _ayat.indexWhere((a) => a.number == ayah) + 1;
    if (index <= 0) return;
    final bottom = MediaQuery.paddingOf(context).bottom + murottalBarExtent;
    final pos = _positions.itemPositions.value
        .where((p) => p.index == index)
        .firstOrNull;
    if (pos != null &&
        pos.itemLeadingEdge >= _barHeight / _viewport &&
        pos.itemTrailingEdge <= 1 - bottom / _viewport) {
      return;
    }
    _scrollTo(index, animate: true);
  }

  void _scrollTo(int index, {bool animate = false}) {
    if (!_scroll.isAttached || _viewport <= 0) return;
    final alignment = (_barHeight + 6) / _viewport;
    if (animate && !MediaQuery.disableAnimationsOf(context)) {
      _scroll.scrollTo(
        index: index,
        alignment: alignment,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _scroll.jumpTo(index: index, alignment: alignment);
    }
  }

  void _toast(String text) {
    final playerUp = ref.read(quranAudioProvider).active;
    _messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
          margin: EdgeInsets.fromLTRB(16, 0, 16, playerUp ? 96 : 16),
        ),
      );
  }

  void _retry() {
    if (ref.read(surahListProvider).hasError) ref.invalidate(surahListProvider);
    ref.invalidate(surahAyatProvider(_n));
  }

  Future<void> _jump() async {
    final ayah = await showJumpToAyahSheet(context, count: _ayat.length);
    if (!mounted || ayah == null) return;
    final index = _ayat.indexWhere((a) => a.number == ayah) + 1;
    if (index > 0) _scrollTo(index);
  }

  void _playSurah() {
    final surah = _surah;
    final audio = _audio;
    if (surah == null || audio == null) return;
    final state = ref.read(quranAudioProvider);
    if (state.active && state.surah == _n) {
      audio.toggle();
    } else {
      audio.playSurah(surah, _ayat, from: _first);
    }
  }

  void _playAyah(Ayah ayah) {
    final surah = _surah;
    final audio = _audio;
    if (surah == null || audio == null) return;
    final state = ref.read(quranAudioProvider);
    if (state.isCurrent(_n, ayah.number)) {
      audio.toggle();
    } else if (state.active && state.surah == _n) {
      audio.playAyah(ayah.number);
    } else {
      audio.playSurah(surah, _ayat, from: ayah.number);
    }
  }

  void _toggleBookmark(Ayah ayah) {
    final added = ref
        .read(ayahBookmarksProvider.notifier)
        .toggle(
          AyahBookmark(
            surah: _n,
            ayah: ayah.number,
            surahName: _surah!.name,
            snippet: bookmarkSnippet(ayah.translation),
            savedAt: DateTime.now(),
          ),
        );
    _toast(
      added
          ? 'Ayat ${ayah.number} ditandai'
          : 'Tanda ayat ${ayah.number} dihapus',
    );
  }

  Future<void> _more(Ayah ayah) async {
    final action = await showAyahMoreSheet(context, ayah: ayah.number);
    if (!mounted || action == null) return;
    switch (action) {
      case AyahMoreAction.tafsir:
        await showAyahTafsirSheet(context, surah: _surah!, ayah: ayah.number);
      case AyahMoreAction.copy:
        await Clipboard.setData(
          ClipboardData(text: ayahShareText(_surah!, ayah)),
        );
        _toast('Ayat ${ayah.number} disalin');
      case AyahMoreAction.markLastRead:
        await _tracker?.markLastRead(ayah.number);
        if (!mounted) return;
        setState(() => _lastReadAyah = ayah.number);
        _toast('Ayat ${ayah.number} jadi terakhir dibaca');
    }
  }

  /// List index of [ayah] (the header for ayah 1, the last ayah past the end).
  static int _indexOf(List<Ayah> ayat, int ayah) {
    if (ayah <= 1) return 0;
    final i = ayat.indexWhere((a) => a.number >= ayah);
    return i < 0 ? ayat.length : i + 1;
  }

  void _openNext() => Navigator.of(context).pushReplacement(
    MaterialPageRoute<void>(
      builder: (_) => QuranReaderScreen(surahNumber: _n + 1),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final surahList = ref.watch(surahListProvider);
    final surah = surahList.valueOrNull?.data
        .where((s) => s.number == _n)
        .firstOrNull;
    final ayatAsync = ref.watch(surahAyatProvider(_n));
    final settings = ref.watch(readingSettingsProvider);
    final palette = ReadingPalette.of(ref.watch(activeReadingThemeProvider));
    final audio = ref.watch(quranAudioProvider);
    _audio = ref.read(quranAudioProvider.notifier);
    ref.listen(quranAudioProvider, _onAudio);
    _night = palette.isDark;

    final ayat = ayatAsync.valueOrNull?.data;
    if (surah == null || ayat == null || ayat.isEmpty) {
      final failed =
          (ayatAsync.hasError && !ayatAsync.isLoading) ||
          (ayat != null && ayat.isEmpty);
      return failed
          ? ReaderNotSaved(
              number: _n,
              surah: surah,
              palette: palette,
              onRetry: _retry,
            )
          : ReaderLoading(palette: palette, title: surah?.name ?? 'Surat $_n');
    }
    _surah = surah;
    _ayat = ayat;
    // Only requested while "Tajwid berwarna" is on; null = plain text.
    final tajweed = settings.tajwid
        ? ref.watch(surahTajweedProvider(_n)).valueOrNull
        : null;
    final tracker = _tracker ??= ReaderProgressTracker(
      surah: surah,
      ayat: ayat,
      saveLastRead: _saveLastRead,
      markJuzDone: ref.read(khatamProvider.notifier).markDone,
    );
    tracker.juz = ref.watch(juzListProvider).valueOrNull?.data ?? const [];
    final start = _startIndex ??= _indexOf(ayat, widget.initialAyah);

    final padding = MediaQuery.paddingOf(context);
    _barHeight = padding.top + 56;
    final current = ayat.firstWhere(
      (a) => a.number == _first,
      orElse: () => ayat.first,
    );
    final marked = {
      for (final b in ref.watch(ayahBookmarksProvider))
        if (b.surah == _n) b.ayah,
    };
    final player = audio.active && audio.surah == _n;
    final next = _n >= QuranRepository.totalSurahs
        ? null
        : surahList.valueOrNull?.data
              .where((s) => s.number == _n + 1)
              .firstOrNull;

    return Scaffold(
      backgroundColor: palette.background,
      body: LayoutBuilder(
        builder: (context, box) {
          _viewport = box.maxHeight;
          return Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: readerPageGradient(palette),
                  ),
                ),
              ),
              Positioned.fill(
                child: ScrollablePositionedList.builder(
                  itemScrollController: _scroll,
                  itemPositionsListener: _positions,
                  initialScrollIndex: start,
                  initialAlignment: start == 0
                      ? 0
                      : (_barHeight + 6) / box.maxHeight,
                  itemCount: ayat.length + 2,
                  itemBuilder: (context, i) {
                    if (i == 0) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ReaderListHeader(
                            surah: surah,
                            palette: palette,
                            barHeight: _barHeight,
                            autoNight: settings.theme != ReadingTheme.malam,
                            playing: player && audio.playing,
                            onPlay: _playSurah,
                            onTafsir: () => showTafsirSheet(context, surah),
                            onMurottal: () =>
                                showMurottalSheet(context, surah, ayat),
                          ),
                          if (tajweed != null)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
                              child: Text(
                                'Tajwid: teks Uthmani dari alquran.cloud',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: palette.muted,
                                ),
                              ),
                            ),
                        ],
                      );
                    }
                    if (i > ayat.length) {
                      return ReaderListFooter(
                        next: next,
                        bottom:
                            padding.bottom + (player ? murottalBarExtent : 0),
                        onNext: _openNext,
                      );
                    }
                    final a = ayat[i - 1];
                    return AyahItem(
                      key: ValueKey('ayah-${a.number}'),
                      ayah: a,
                      palette: palette,
                      settings: settings,
                      tajweed: tajweed?[a.number],
                      current: audio.isCurrent(_n, a.number),
                      playing: audio.playing,
                      bookmarked: marked.contains(a.number),
                      lastRead: _lastReadAyah == a.number,
                      onPlay: () => _playAyah(a),
                      onBookmark: () => _toggleBookmark(a),
                      onShare: () => showShareAyahSheet(
                        context,
                        surah: surah,
                        ayah: a,
                        template: palette.isDark
                            ? ShareTemplate.malam
                            : ShareTemplate.senja,
                      ),
                      onMore: () => _more(a),
                    );
                  },
                ),
              ),
              if (player)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 150 + padding.bottom,
                  child: PlayerFade(color: palette.backgroundEnd),
                ),
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                child: ReaderAppBar(
                  title: surah.name,
                  subtitle: 'Juz ${current.juz} · Hal. ${current.page}',
                  palette: palette,
                  opacity: palette.isDark ? _headerScroll / 120 : 1,
                  onSettings: () => showReadingSettingsSheet(context),
                  onJump: _jump,
                  onMushaf: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          MushafPageScreen(initialPage: current.page),
                    ),
                  ),
                ),
              ),
              if (player)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: MurottalBar(
                    state: audio,
                    progress: _audio!.progress,
                    onPrevious: _audio!.previous,
                    onToggle: _audio!.toggle,
                    onNext: _audio!.next,
                    onStop: _audio!.stop,
                    night: palette.isDark,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
