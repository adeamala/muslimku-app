class HadithModel {
  final int nomor;
  final String arab;
  final String indo;
  final String kitab;
  final String slug;

  HadithModel({
    required this.nomor,
    required this.arab,
    required this.indo,
    required this.kitab,
    required this.slug,
  });

  factory HadithModel.fromJson(Map<String, dynamic> json) {
    return HadithModel(
      nomor: _asInt(json['no'] ?? json['nomor'] ?? json['number']),
      arab: (json['ar'] ?? json['arab'] ?? '') as String,
      indo: (json['id'] ?? json['indo'] ?? '') as String,
      kitab: (json['kitab'] ?? 'Hadith') as String,
      slug: (json['slug'] ?? '') as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'nomor': nomor,
      'arab': arab,
      'indo': indo,
      'kitab': kitab,
      'slug': slug,
    };
  }
}

class HadithArbainModel {
  final int nomor;
  final String arab;
  final String indo;
  final String judul;

  HadithArbainModel({
    required this.nomor,
    required this.arab,
    required this.indo,
    this.judul = '',
  });

  factory HadithArbainModel.fromJson(Map<String, dynamic> json) {
    return HadithArbainModel(
      nomor: _asInt(json['nomor'] ?? json['no']),
      arab: (json['arab'] ?? '') as String,
      indo: (json['indo'] ?? '') as String,
      judul: json['judul']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {'nomor': nomor, 'arab': arab, 'indo': indo};
  }
}

/// MyQuran sends numbers as int or string (and sometimes an empty string).
int _asInt(Object? value) =>
    value is int ? value : int.tryParse('${value ?? ''}') ?? 0;

// ---------------------------------------------------------------------------
// Hadits tab (design-v2): one model for Arbain, Bulughul Maram and 9 perawi.

/// A hadith collection: Arbain An-Nawawi, Bulughul Maram or a perawi's book.
class HaditsBook {
  const HaditsBook({
    required this.slug,
    required this.name,
    required this.total,
    this.arabicName = '',
  });

  static const arbain = HaditsBook(slug: 'arbain', name: 'Arbain', total: 42);
  static const bulughulMaram = HaditsBook(
    slug: 'bm',
    name: 'Bulughul Maram',
    total: 1597,
  );

  /// The 9 perawi in display order with the totals of `hadits/perawi`
  /// (October 2026), so the grid shows before (or without) the download.
  static const perawi = [
    HaditsBook(
      slug: 'bukhari',
      name: 'Bukhari',
      arabicName: 'البخاري',
      total: 6638,
    ),
    HaditsBook(slug: 'muslim', name: 'Muslim', arabicName: 'مسلم', total: 4930),
    HaditsBook(
      slug: 'abu-dawud',
      name: 'Abu Dawud',
      arabicName: 'أبو داود',
      total: 4419,
    ),
    HaditsBook(
      slug: 'tirmidzi',
      name: 'Tirmidzi',
      arabicName: 'الترمذي',
      total: 3625,
    ),
    HaditsBook(
      slug: 'nasai',
      name: 'Nasai',
      arabicName: 'النسائي',
      total: 5364,
    ),
    HaditsBook(
      slug: 'ibnu-majah',
      name: 'Ibnu Majah',
      arabicName: 'ابن ماجه',
      total: 4285,
    ),
    HaditsBook(slug: 'ahmad', name: 'Ahmad', arabicName: 'أحمد', total: 4305),
    HaditsBook(slug: 'malik', name: 'Malik', arabicName: 'مالك', total: 1587),
    HaditsBook(
      slug: 'darimi',
      name: 'Darimi',
      arabicName: 'الدارمي',
      total: 2949,
    ),
  ];

  /// `arbain`, `bm` or a perawi slug such as `bukhari` (MyQuran paths).
  final String slug;
  final String name;
  final String arabicName;

  /// Number of hadiths; valid numbers are 1..total.
  final int total;

  bool get isArbain => slug == arbain.slug;
  bool get isBulughulMaram => slug == bulughulMaram.slug;
  bool get isPerawi => !isArbain && !isBulughulMaram;

  /// Tag on the detail page: "Arbain An-Nawawi", "Bulughul Maram", "HR. Bukhari".
  String get sourceLabel => isArbain
      ? 'Arbain An-Nawawi'
      : isBulughulMaram
      ? name
      : 'HR. $name';

  /// The known book for [slug] (Arbain, Bulughul Maram or a perawi).
  static HaditsBook? bySlug(String slug) {
    for (final book in [arbain, bulughulMaram, ...perawi]) {
      if (book.slug == slug) return book;
    }
    return null;
  }

  HaditsBook withTotal(int total) =>
      HaditsBook(slug: slug, name: name, arabicName: arabicName, total: total);

  @override
  bool operator ==(Object other) =>
      other is HaditsBook && other.slug == slug && other.total == total;

  @override
  int get hashCode => Object.hash(slug, total);

  @override
  String toString() => 'HaditsBook($slug, $total)';
}

/// One hadith of any [HaditsBook], with MyQuran's text cleaned up.
class HaditsEntry {
  HaditsEntry({
    required this.book,
    required this.number,
    required this.arab,
    required this.translation,
    this.title = '',
  });

  /// An item of `hadits/arbain/semua`: `no` (string), `judul`, `arab`, `indo`.
  factory HaditsEntry.arbain(Map<String, dynamic> json) => HaditsEntry(
    book: HaditsBook.arbain,
    number: _asInt(json['no'] ?? json['nomor']),
    arab: cleanHaditsArabic('${json['arab'] ?? ''}'),
    translation: cleanHaditsTranslation('${json['indo'] ?? ''}'),
    title: '${json['judul'] ?? ''}'.trim(),
  );

  /// `hadits/bm/<n>`: `no`, `ar`, `id` (starts with "Hadis No. n" and `\r`).
  factory HaditsEntry.bulughulMaram(
    Map<String, dynamic> json, {
    int number = 0,
  }) => HaditsEntry(
    book: HaditsBook.bulughulMaram,
    number: _asInt(json['no']) > 0 ? _asInt(json['no']) : number,
    arab: cleanHaditsArabic('${json['ar'] ?? json['arab'] ?? ''}'),
    translation: cleanHaditsTranslation('${json['id'] ?? ''}'),
  );

  /// `hadits/<slug>/<n>`: `number`, `arab`, `id`.
  factory HaditsEntry.perawi(
    HaditsBook book,
    Map<String, dynamic> json, {
    int number = 0,
  }) => HaditsEntry(
    book: book,
    number: _asInt(json['number']) > 0 ? _asInt(json['number']) : number,
    arab: cleanHaditsArabic('${json['arab'] ?? json['ar'] ?? ''}'),
    translation: cleanHaditsTranslation('${json['id'] ?? ''}'),
  );

  final HaditsBook book;
  final int number;
  final String arab;
  final String translation;

  /// Arbain only ("Janganlah Engkau Marah").
  final String title;

  /// "HR. Bukhari & Muslim" for Arbain, the book's label otherwise.
  late final String citation = book.isArbain
      ? arbainCitation(translation)
      : book.sourceLabel;

  /// The core quote of the translation, for cards and list rows.
  late final String excerpt = quoteExcerpt(translation);

  /// Key in `favoritesProvider('hadits')`, e.g. `arbain:16` or `bm:12`.
  String get favoriteKey => '${book.slug}:$number';

  /// The model of the Beranda hadith card (Arbain).
  HadithArbainModel toArbainModel() => HadithArbainModel(
    nomor: number,
    arab: arab,
    indo: translation,
    judul: title,
  );
}

const _defaultCitation = 'Arbain An-Nawawi';

/// Narrators in the order the citation is checked, with tolerant patterns
/// (MyQuran writes "Al Bukhari", "Al-Bukhari", "At Tirmdzi", "An Nasa'i").
const _narrators = [
  ('Bukhari', r'bukhari'),
  ('Muslim', r'muslim'),
  ('Abu Dawud', r'abu\s*dawud'),
  ('Tirmidzi', r'tirmi?dz?i'),
  ('Nasa’i', r"nasa['’`]?i"),
  ('Ibnu Majah', r'ibnu?\s*majah'),
  ('Ahmad', r'ahmad'),
  ('Malik', r'malik'),
  ('Daruquthni', r'daruqu?th?ni'),
  ('Baihaqi', r'baihaqi'),
  ('Thabrani', r'th?abrani'),
  ('Baghawi', r'baghawi'),
];

final _hrPattern = RegExp(r'[(\[]\s*(HR\b[^()\[\]]*)[)\]]');

/// "HR. Bukhari & Muslim", "HR. Muslim" … from an Arbain translation.
///
/// MyQuran puts the citation mid-text as `(HR ...)` and adds "Diriwayatkan
/// oleh …" with more books after it, so the first `(HR` wins. Without one,
/// the sentence that starts with "diriwayatkan oleh" is used.
String arbainCitation(String text) {
  final hr = _hrPattern.firstMatch(text);
  final source = (hr?.group(1) ?? _narratedBySentence(text)).toLowerCase();
  if (source.isEmpty) return _defaultCitation;
  final hits = <(int, String)>[];
  for (final (name, pattern) in _narrators) {
    final at = RegExp(pattern).firstMatch(source)?.start;
    if (at != null) hits.add((at, name));
  }
  final names = {for (final hit in hits) hit.$2};
  if (names.contains('Bukhari') && names.contains('Muslim')) {
    return 'HR. Bukhari & Muslim';
  }
  if (hits.isEmpty) return _defaultCitation;
  hits.sort((a, b) => a.$1.compareTo(b.$1));
  return 'HR. ${hits.first.$2}';
}

/// From "diriwayatkan oleh" to the end of its sentence or parenthesis.
String _narratedBySentence(String text) {
  final start = text.toLowerCase().indexOf('diriwayatkan oleh');
  if (start < 0) return '';
  var depth = 0;
  for (var i = start; i < text.length; i++) {
    final c = text[i];
    if (c == '(') {
      depth++;
    } else if (c == ')') {
      if (depth == 0) return text.substring(start, i);
      depth--;
    } else if (c == '.' && depth == 0) {
      final rest = text.substring(i + 1).trimLeft();
      final spaced = i + 1 >= text.length || text[i + 1].trim().isEmpty;
      if (spaced && (rest.isEmpty || rest[0] != rest[0].toLowerCase())) {
        return text.substring(start, i);
      }
    }
  }
  return text.substring(start);
}

const _quoteMarks = '“”"';

/// The quoted words of the Prophet (or the first quote) of [text], e.g.
/// `”Berilah aku nasihat.” Beliau … bersabda: ”Janganlah engkau marah.”`.
/// Without quotes, the text after "bersabda:" (about [maxLength] characters).
String quoteExcerpt(String text, {int maxLength = 110}) {
  final quotes = _quotes(text);
  if (quotes.isNotEmpty) {
    final first = quotes.first;
    if (first.text.length < 40 &&
        quotes.length > 1 &&
        quotes[1].text != first.text) {
      final second = quotes[1];
      final bridge = _bridge(text.substring(first.end + 1, second.start));
      return '”${first.text}” $bridge${_quoted(second.text, 120)}';
    }
    return _quoted(first.text, 158);
  }
  final flat = _flat(text);
  final said = flat.toLowerCase().indexOf('bersabda:');
  final body = said < 0 ? flat : flat.substring(said + 9).trim();
  return _shorten(body.isEmpty ? flat : body, maxLength);
}

String _quoted(String quote, int max) {
  final short = _shorten(quote, max);
  return short.endsWith('…') ? '”$short' : '”$short”';
}

/// The words between two quotes, shortened to "Beliau … bersabda: ".
String _bridge(String between) {
  final words = _flat(between).split(' ').where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) return '… ';
  if (words.length <= 3) return '${words.join(' ')} ';
  return '${words.first} … ${words.last} ';
}

/// Quotes of [text] with the positions of their marks (`end` is the
/// closing mark, or the end of the text for an unclosed quote).
List<({int start, int end, String text})> _quotes(String text) {
  bool isMark(int i) => _quoteMarks.contains(text[i]);
  int next(int from) {
    for (var i = from; i < text.length; i++) {
      if (isMark(i)) return i;
    }
    return -1;
  }

  final out = <({int start, int end, String text})>[];
  var from = 0;
  while (true) {
    final open = next(from);
    if (open < 0) break;
    final close = next(open + 1);
    final inner = _flat(
      close < 0
          ? _beforeCitation(text.substring(open + 1))
          : text.substring(open + 1, close),
    );
    if (close >= 0 && inner.endsWith(':')) {
      from = close; // ”Rasulullah bersabda: ”…” — the real quote starts here
      continue;
    }
    if (inner.length >= 3) {
      out.add((start: open, end: close < 0 ? text.length : close, text: inner));
    }
    if (close < 0) break;
    from = close + 1;
  }
  return out;
}

String _beforeCitation(String text) {
  final end = RegExp(
    r'[(\[]\s*HR\b|diriwayatkan oleh',
    caseSensitive: false,
  ).firstMatch(text)?.start;
  return end == null ? text : text.substring(0, end);
}

String _flat(String text) => text.replaceAll(RegExp(r'\s+'), ' ').trim();

/// [text] cut at a word before [max] characters, with "…".
String _shorten(String text, int max) {
  if (text.length <= max) return text;
  var cut = text.lastIndexOf(' ', max);
  if (cut < max ~/ 2) cut = max;
  final head = text.substring(0, cut).replaceFirst(RegExp(r'[\s,.;:]+$'), '');
  return '$head…';
}

/// Translation without MyQuran's "Hadis No. 12 \r" header, html tags,
/// carriage returns and double spaces.
String cleanHaditsTranslation(String text) => _flat(
  text
      .replaceAll(RegExp(r'<[^>]*>'), '')
      .replaceFirst(
        RegExp(r'^\s*Hadis\s*No\.?\s*\d+', caseSensitive: false),
        '',
      ),
);

/// Arabic text without html tags (`<b>` in Bulughul Maram) and double spaces.
String cleanHaditsArabic(String text) =>
    _flat(text.replaceAll(RegExp(r'<[^>]*>'), ''));
