/// Small formatting helpers of the Hadits tab.
library;

import 'package:muslimku/features/hadith/domain/hadith_model.dart';

/// Search of the Arbain list: a number ("16", "no 16") matches numbers that
/// start with it, any other text the title (case-insensitive).
bool matchesArbainQuery(HaditsEntry entry, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return true;
  final number = RegExp(r'^(?:no\.?\s*)?(\d+)$').firstMatch(q)?.group(1);
  if (number != null) return '${entry.number}'.startsWith(number);
  return entry.title.toLowerCase().contains(q);
}

/// `6638` → `6.638` (Indonesian thousand separator).
String formatRibuan(int value) {
  final digits = value.abs().toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => '.',
  );
  return value < 0 ? '-$digits' : digits;
}

/// Where a hadith comes from, e.g. "Arbain An-Nawawi No. 16, HR. Bukhari",
/// "Bulughul Maram No. 12" or "HR. Bukhari No. 52".
String haditsReference(HaditsEntry entry) {
  final book = entry.book;
  if (book.isArbain) {
    return '${book.sourceLabel} No. ${entry.number}, ${entry.citation}';
  }
  return '${book.sourceLabel} No. ${entry.number}';
}

/// Text for "Salin" and "Bagikan" on the detail page.
String haditsShareText(HaditsEntry entry) => [
  if (entry.title.isNotEmpty) entry.title,
  if (entry.arab.isNotEmpty) entry.arab,
  entry.translation,
  '(${haditsReference(entry)})\n\nDibagikan dari aplikasi Muslimku',
].join('\n\n');
