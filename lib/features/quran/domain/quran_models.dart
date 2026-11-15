import 'package:muslimku/core/utils/arabic_text.dart';
import 'package:muslimku/features/quran/domain/reciters.dart';

int _int(Object? value, [int fallback = 0]) =>
    value is int ? value : int.tryParse('${value ?? ''}'.trim()) ?? fallback;

String _str(Object? value) => value == null ? '' : '$value'.trim();

/// A surah from MyQuran `quran/surat/semua` or `quran/surat/<n>`.
class Surah {
  const Surah({
    required this.number,
    required this.name,
    required this.arabicName,
    required this.meaning,
    required this.revelation,
    required this.verseCount,
    this.tafsir = '',
    this.audioUrl,
  });

  factory Surah.fromJson(Map<String, dynamic> json) {
    final audio = _str(json['audio_url']);
    return Surah(
      number: _int(json['number']),
      name: _str(json['name_id']),
      arabicName: _str(json['name_short']),
      meaning: _str(json['translation_id']),
      revelation: _str(json['revelation_id']),
      verseCount: _int(json['number_of_verses']),
      tafsir: _str(json['tafsir']),
      audioUrl: audio.isEmpty ? null : audio,
    );
  }

  final int number;

  /// Latin name, e.g. "Al-Baqarah".
  final String name;

  /// Arabic name, e.g. "البقرة".
  final String arabicName;

  /// Indonesian meaning, e.g. "Sapi".
  final String meaning;

  /// "Makkiyyah" or "Madaniyyah".
  final String revelation;
  final int verseCount;

  /// Short Indonesian introduction to the surah.
  final String tafsir;

  /// Full-surah recitation by Mishary Alafasy (quranicaudio.com).
  final String? audioUrl;

  bool get isMakkiyyah => revelation.toLowerCase().startsWith('makk');

  /// Every surah except Al-Fatihah (where it is ayah 1) and At-Taubah.
  bool get showsBismillah => number != 1 && number != 9;
}

/// An ayah from MyQuran `quran/ayat/...`.
class Ayah {
  const Ayah({
    required this.id,
    required this.surah,
    required this.number,
    required this.arab,
    required this.latin,
    required this.translation,
    required this.juz,
    required this.page,
  });

  factory Ayah.fromJson(Map<String, dynamic> json) => Ayah(
    id: _int(json['id']),
    surah: _int(json['surah']),
    number: _int(json['ayah']),
    arab: normalizeQuranText(_str(json['arab'])),
    latin: _str(json['latin']),
    translation: _str(json['text']),
    juz: _int(json['juz']),
    page: _int(json['page']),
  );

  /// Position in the whole Qur'an (1–6236).
  final int id;
  final int surah;

  /// Number inside the surah.
  final int number;
  final String arab;
  final String latin;

  /// Indonesian translation (Kemenag).
  final String translation;
  final int juz;
  final int page;

  Map<String, dynamic> toJson() => {
    'id': id,
    'surah': surah,
    'ayah': number,
    'arab': arab,
    'latin': latin,
    'text': translation,
    'juz': juz,
    'page': page,
  };

  /// Recitation of this ayah by Mishary Alafasy on the Islamic Network CDN.
  /// (MyQuran's own `audio` field points at cdn.alquran.cloud, which is gone.)
  String get audioUrl => audioUrlFor(Reciter.alafasy);

  /// Recitation of this ayah by [reciter].
  String audioUrlFor(Reciter reciter) => reciter.url(id);
}

/// A juz from MyQuran `quran/juz/semua`.
class JuzInfo {
  const JuzInfo({
    required this.number,
    required this.startSurah,
    required this.startVerse,
    required this.endSurah,
    required this.endVerse,
    required this.startName,
    required this.endName,
    required this.opening,
  });

  factory JuzInfo.fromJson(Map<String, dynamic> json) {
    final words = _str(json['ayat_arab'])
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty && w != '۞')
        .take(2)
        .join(' ');
    return JuzInfo(
      number: _int(json['number']),
      startSurah: _int(json['surah_id_start']),
      startVerse: _int(json['verse_start'], 1),
      endSurah: _int(json['surah_id_end']),
      endVerse: _int(json['verse_end']),
      startName: _str(json['name_start_id']),
      endName: _str(json['name_end_id']),
      opening: words,
    );
  }

  final int number;
  final int startSurah;
  final int startVerse;
  final int endSurah;
  final int endVerse;
  final String startName;
  final String endName;

  /// First words of the juz in Arabic, e.g. "سَيَقُولُ السُّفَهَاءُ".
  final String opening;

  /// "Al-Fatihah 1 – Al-Baqarah 141".
  String get range => '$startName $startVerse – $endName $endVerse';

  bool contains(int surah, int ayah) {
    final afterStart =
        surah > startSurah || (surah == startSurah && ayah >= startVerse);
    final beforeEnd =
        surah < endSurah || (surah == endSurah && ayah <= endVerse);
    return afterStart && beforeEnd;
  }

  bool endsAt(int surah, int ayah) => surah == endSurah && ayah == endVerse;
}
