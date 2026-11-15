import 'package:muslimku/features/quran/domain/quran_models.dart';

/// Kemenag translations carry footnote numbers right after a word, e.g.
/// "Alif Lām Mīm.4)" or "mengikutinya638) dan". The reader shows no footnotes,
/// so they are dropped. Numbers after a space, "(", ":" or "/" stay.
final RegExp _footnote = RegExp(
  r"(?<=[A-Za-z\u00C0-\u024F\u1E00-\u1EFF.,;!?’”'\x22)])\d{1,4}\)",
);

String cleanTranslation(String text) =>
    text.replaceAll(_footnote, '').replaceAll(RegExp(r'  +'), ' ').trim();

/// "QS Asy-Syarh 94:5".
String ayahReference(Surah surah, int ayah) =>
    'QS ${surah.name} ${surah.number}:$ayah';

/// Text for "Salin ayat" / "Salin teks": Arabic, the translation in quotes and
/// the reference.
String ayahShareText(Surah surah, Ayah ayah, {bool translation = true}) {
  final meaning = cleanTranslation(ayah.translation);
  return [
    ayah.arab,
    if (translation && meaning.isNotEmpty) '“$meaning”',
    ayahReference(surah, ayah.number),
  ].join('\n\n');
}

/// Start of the translation (about 90 characters) for the bookmark list.
String bookmarkSnippet(String translation, {int max = 90}) {
  final text = cleanTranslation(translation);
  if (text.length <= max) return text;
  final cut = text.substring(0, max);
  final space = cut.lastIndexOf(' ');
  return '${(space > max * 0.6 ? cut.substring(0, space) : cut).trimRight()}…';
}
