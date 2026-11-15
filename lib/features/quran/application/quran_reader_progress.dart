import 'dart:async';

import 'package:muslimku/features/quran/application/quran_progress_provider.dart';
import 'package:muslimku/features/quran/domain/quran_models.dart';

/// Keeps "Terakhir dibaca" and "Progres khatam" up to date while a surah is
/// open in the reader.
///
/// - The first visible ayah is saved as [LastRead] once scrolling has settled
///   for [debounce], and right away on [flush] (when the reader closes).
/// - A juz counts as read when its last ayah has been on screen.
/// - After "Tandai terakhir dibaca" ([markLastRead]) scrolling no longer moves
///   the saved position.
class ReaderProgressTracker {
  ReaderProgressTracker({
    required this.surah,
    required this.ayat,
    required this.saveLastRead,
    required this.markJuzDone,
    this.juz = const [],
    this.debounce = const Duration(seconds: 1),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final Surah surah;
  final List<Ayah> ayat;
  final Future<void> Function(LastRead value) saveLastRead;
  final void Function(int juz) markJuzDone;

  /// Juz boundaries; may arrive after the reader opened.
  List<JuzInfo> juz;
  final Duration debounce;
  final DateTime Function() _clock;

  Timer? _timer;
  int? _pending;
  int? _saved;
  bool _manual = false;
  final Set<int> _done = {};

  /// Whether a position of this visit was saved already.
  bool get hasSaved => _saved != null;

  /// The reader shows ayah [first] at the top and [visible] on screen.
  void update(int first, Iterable<int> visible) {
    for (final ayah in visible) {
      for (final j in juz) {
        if (j.endsAt(surah.number, ayah) && _done.add(j.number)) {
          markJuzDone(j.number);
        }
      }
    }
    if (_manual) return;
    _pending = first;
    _timer?.cancel();
    _timer = Timer(debounce, flush);
  }

  /// "Tandai terakhir dibaca": saves [ayah] now and stops following the scroll.
  Future<void> markLastRead(int ayah) {
    _manual = true;
    _timer?.cancel();
    _timer = null;
    _pending = null;
    return _save(ayah);
  }

  /// Saves the waiting position now (e.g. when leaving the reader).
  void flush() {
    _timer?.cancel();
    _timer = null;
    final ayah = _pending;
    _pending = null;
    if (ayah == null || ayah == _saved) return;
    _save(ayah);
  }

  Future<void> _save(int number) {
    _saved = number;
    final ayah = ayat.where((a) => a.number == number).firstOrNull;
    return saveLastRead(
      LastRead(
        surah: surah.number,
        ayah: number,
        surahName: surah.name,
        verseCount: surah.verseCount,
        juz: ayah?.juz ?? 0,
        page: ayah?.page ?? 0,
        updatedAt: _clock(),
      ),
    );
  }

  void dispose() => flush();
}
