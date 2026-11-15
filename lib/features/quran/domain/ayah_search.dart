import 'package:muslimku/core/storage/local_store.dart';
import 'package:muslimku/features/quran/data/quran_repository.dart';
import 'package:muslimku/features/quran/domain/quran_models.dart';

/// Lower case, Latin diacritics stripped (ā→a, ż→z, ḥ→h …), punctuation
/// other than hyphens dropped, spaces collapsed.
String foldForSearch(String s) {
  final sb = StringBuffer();
  for (final rune in s.toLowerCase().runes) {
    final ch = String.fromCharCode(rune);
    sb.write(_fold[ch] ?? ch);
  }
  return sb
      .toString()
      .replaceAll(RegExp(r"[’‘`´']"), '')
      .replaceAll(RegExp(r'[^a-z0-9\s-]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

const _fold = {
  'ā': 'a',
  'á': 'a',
  'à': 'a',
  'â': 'a',
  'ä': 'a',
  'ī': 'i',
  'í': 'i',
  'ì': 'i',
  'î': 'i',
  'ï': 'i',
  'ū': 'u',
  'ú': 'u',
  'ù': 'u',
  'û': 'u',
  'ü': 'u',
  'ē': 'e',
  'é': 'e',
  'è': 'e',
  'ê': 'e',
  'ë': 'e',
  'ō': 'o',
  'ó': 'o',
  'ò': 'o',
  'ô': 'o',
  'ö': 'o',
  'ż': 'z',
  'ẓ': 'z',
  'ž': 'z',
  'ṣ': 's',
  'š': 's',
  'ṡ': 's',
  'ś': 's',
  'ḥ': 'h',
  'ḫ': 'h',
  'ḍ': 'd',
  'ḏ': 'd',
  'ṭ': 't',
  'ṯ': 't',
  'ġ': 'g',
  'ñ': 'n',
  'ç': 'c',
  'ʻ': '',
  'ʼ': '',
  'ʿ': '',
  'ʾ': '',
};

/// Minimum query length that counts as a search.
const ayahSearchMinLength = 3;

/// Every word of [query] (≥ 3 letters in total) appears in the translation
/// or the transliteration.
bool ayahMatches(Ayah ayah, String query) {
  final q = foldForSearch(query);
  if (q.length < ayahSearchMinLength) return false;
  final words = q.split(' ').where((w) => w.isNotEmpty);
  final text =
      '${foldForSearch(ayah.translation)} ${foldForSearch(ayah.latin)}';
  return words.every(text.contains);
}

/// Character ranges of [text] (as displayed) where a query word starts,
/// for highlighting. Works on the folded text, so lengths line up only
/// when folding keeps one char per char, which it does for Indonesian.
List<(int, int)> highlightRanges(String text, String query) {
  final folded = foldForSearch(text);
  if (folded.length != text.length) return const [];
  final out = <(int, int)>[];
  for (final word in foldForSearch(query).split(' ')) {
    if (word.isEmpty) continue;
    var from = 0;
    while (true) {
      final i = folded.indexOf(word, from);
      if (i < 0) break;
      out.add((i, i + word.length));
      from = i + word.length;
    }
  }
  out.sort((a, b) => a.$1.compareTo(b.$1));
  return out;
}

class AyahSearchResult {
  const AyahSearchResult({required this.ayah, required this.surahName});

  final Ayah ayah;
  final String surahName;
}

/// Scans the surahs saved on the phone, in surah order, for [query];
/// at most [limit] results. Nothing goes to the network.
Future<List<AyahSearchResult>> searchSavedAyat(
  LocalStore store,
  String query, {
  int limit = 200,
  Map<int, String> surahNames = const {},
}) async {
  if (foldForSearch(query).length < ayahSearchMinLength) return const [];
  final keys = await store.keys(QuranRepository.surahPrefix);
  final numbers = [
    for (final key in keys)
      if (int.tryParse(
            key.substring(QuranRepository.surahPrefix.length).split('.').first,
          )
          case final n?)
        n,
  ]..sort();
  final out = <AyahSearchResult>[];
  for (final surah in numbers) {
    final json = await store.readJson(QuranRepository.surahKey(surah));
    if (json is! List) continue;
    for (final row in json) {
      if (row is! Map) continue;
      final ayah = Ayah.fromJson(Map<String, dynamic>.from(row));
      if (!ayahMatches(ayah, query)) continue;
      out.add(
        AyahSearchResult(
          ayah: ayah,
          surahName:
              surahNames[surah] ?? _defaultNames[surah] ?? 'Surat $surah',
        ),
      );
      if (out.length >= limit) return out;
    }
  }
  return out;
}

/// Names used when the surah list is not loaded (first two only; the
/// screen passes the real list).
const _defaultNames = {1: 'Al-Fatihah', 2: 'Al-Baqarah'};
