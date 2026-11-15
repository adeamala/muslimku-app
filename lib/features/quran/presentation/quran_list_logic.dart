import 'dart:math' as math;

import 'package:muslimku/features/quran/application/quran_progress_provider.dart';
import 'package:muslimku/features/quran/data/quran_repository.dart';
import 'package:muslimku/features/quran/domain/quran_models.dart';

/// "Semua / Makkiyyah / Madaniyyah" in the filter sheet of the surah list.
enum RevelationFilter {
  all('Semua'),
  makkiyyah('Makkiyyah'),
  madaniyyah('Madaniyyah');

  const RevelationFilter(this.label);

  final String label;

  bool accepts(Surah surah) => switch (this) {
    RevelationFilter.all => true,
    RevelationFilter.makkiyyah => surah.isMakkiyyah,
    RevelationFilter.madaniyyah => !surah.isMakkiyyah,
  };
}

final _arabicLetters = RegExp(r'[\u0600-\u06FF]');
final _notLatinOrDigit = RegExp(r'[^a-z0-9]');
final _repeated = RegExp(r'(.)\1+');
final _digraphs = <(Pattern, String)>[
  ('gh', 'g'),
  ('dz', 'z'),
  ('dh', 'd'),
  ('ts', 's'),
  ('th', 't'),
  ('sh', 'sy'),
];

/// Lower case without spaces, apostrophes and hyphens, with common
/// transliteration variants folded together ("Adz-Dzariyat" = "Az-Zariyat",
/// "Yaasiin" = "Yasin"), so search ignores how a name is spelled.
String foldSurahText(String text) {
  var folded = text.toLowerCase().replaceAll(_notLatinOrDigit, '');
  for (final (from, to) in _digraphs) {
    folded = folded.replaceAll(from, to);
  }
  return folded.replaceAllMapped(_repeated, (m) => m[1]!);
}

/// Surahs matching [query] (number, latin name, meaning or Arabic name) and
/// [filter], in their original order. A number finds only that surah.
List<Surah> filterSurahs(
  List<Surah> surahs, {
  String query = '',
  RevelationFilter filter = RevelationFilter.all,
}) {
  final trimmed = query.trim();
  final number = int.tryParse(trimmed);
  final folded = foldSurahText(trimmed);
  final arabic = _arabicLetters.hasMatch(trimmed);
  bool matches(Surah s) {
    if (trimmed.isEmpty) return true;
    if (number != null) return s.number == number;
    if (arabic) return s.arabicName.contains(trimmed);
    if (folded.isEmpty) return true;
    return foldSurahText(s.name).contains(folded) ||
        foldSurahText(s.meaning).contains(folded);
  }

  return [
    for (final s in surahs)
      if (filter.accepts(s) && matches(s)) s,
  ];
}

/// One of the 30 marks in "Progres khatam".
enum KhatamTick { done, current, pending }

const _totalJuz = 30;

bool _isJuz(int n) => n >= 1 && n <= _totalJuz;

/// Ticks for juz 1–30: [done] are finished, [currentJuz] (the juz of the
/// last read ayah) is highlighted even when it was finished before.
List<KhatamTick> khatamTicks(Set<int> done, {int? currentJuz}) => [
  for (var juz = 1; juz <= _totalJuz; juz++)
    juz == currentJuz
        ? KhatamTick.current
        : done.contains(juz)
        ? KhatamTick.done
        : KhatamTick.pending,
];

/// Finished juz, ignoring anything outside 1–30.
int khatamDoneCount(Set<int> done) => done.where(_isJuz).length;

/// "Ayat 12 dari 83 · Juz 22 · Hal. 441" under the surah name on
/// "Lanjutkan membaca"; unknown parts are left out.
String lastReadDetail(LastRead read) => [
  read.verseCount > 0
      ? 'Ayat ${read.ayah} dari ${read.verseCount}'
      : 'Ayat ${read.ayah}',
  if (read.juz > 0) 'Juz ${read.juz}',
  if (read.page > 0) 'Hal. ${read.page}',
].join(' · ');

/// "Juz 22 · Yasin ayat 12" in "Sedang dibaca" on the Juz tab.
String readingNowLabel(LastRead read) => [
  if (read.juz > 0) 'Juz ${read.juz}',
  '${read.surahName} ayat ${read.ayah}',
].join(' · ');

/// Approximate size of saved data: "±4,5 MB", "±40 KB" or "0 MB".
String formatSavedSize(int bytes) {
  if (bytes <= 0) return '0 MB';
  if (bytes < 1000000) return '±${math.max(1, (bytes / 1000).round())} KB';
  final tenths = (bytes / 100000).round();
  final whole = tenths ~/ 10;
  final rest = tenths % 10;
  return rest == 0 ? '±$whole MB' : '±$whole,$rest MB';
}

/// The button on "Simpan Al-Qur'an di HP".
enum DownloadAction {
  start('Unduh'),
  resume('Lanjutkan'),
  cancel('Batal'),
  none('');

  const DownloadAction(this.label);

  final String label;
}

DownloadAction downloadActionFor(QuranDownloadState state) => state.running
    ? DownloadAction.cancel
    : state.complete
    ? DownloadAction.none
    : state.storedSurahs == 0
    ? DownloadAction.start
    : DownloadAction.resume;

/// Estimated size of the whole Qur'an text (README of design-v2).
const quranTotalSizeLabel = '±6 MB';

/// Line under the progress bar of "Simpan Al-Qur'an di HP".
String downloadCaption(QuranDownloadState state) {
  if (state.complete) {
    return 'Semua surat tersimpan · ${formatSavedSize(state.storedBytes)}';
  }
  if (!state.running && state.storedBytes <= 0) {
    return '$quranTotalSizeLabel untuk ${QuranRepository.totalSurahs} surat';
  }
  final size =
      '${formatSavedSize(state.storedBytes)} dari $quranTotalSizeLabel';
  return state.running
      ? '$size · juz ${state.doneJuz}/${QuranRepository.totalJuz}'
      : size;
}

/// "Al-Baqarah 142 –" and "Al-Baqarah 252" on two lines, so a juz card never
/// breaks inside a name ("Al-" / "Baqarah").
String juzRangeText(JuzInfo juz) =>
    '${juz.startName} ${juz.startVerse} –\n${juz.endName} ${juz.endVerse}';
