/// Quranic text helpers.
library;

/// MyQuran (Kemenag) writes some Quranic marks after a space, e.g. Yasin 1 is
/// `يٰسۤ ۚ`. Amiri then draws the lone mark floating high above the line, so
/// attach it to the word before. U+06DD (end of ayah), U+06DE (rub el hizb),
/// U+06E5/U+06E6 (small waw/yeh) and U+06E9 (sajdah) are left alone.
final RegExp _detachedMark = RegExp(
  r'\s+([\u06D6-\u06DC\u06DF-\u06E4\u06E7\u06E8\u06EA-\u06ED])',
);

String normalizeQuranText(String text) =>
    text.replaceAllMapped(_detachedMark, (m) => m.group(1)!).trim();

/// Arabic for the bismillah as written by MyQuran (Al-Fatihah 1).
const bismillah = 'بِسْمِ اللّٰهِ الرَّحْمٰنِ الرَّحِيْمِ';

/// 286 → "٢٨٦" (Arabic-Indic digits, for ayah markers on a mushaf page).
String arabicIndic(int n) => n
    .toString()
    .split('')
    .map((d) => String.fromCharCode(0x0660 + int.parse(d)))
    .join();
