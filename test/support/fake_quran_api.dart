import 'package:muslimku/core/network/api_service.dart';
import 'package:muslimku/features/quran/domain/quran_models.dart';

/// MyQuran stand-in for Qur'an data: Al-Fatihah (7 ayat, juz 1) and a short
/// "Al-Baqarah" of 40 ayat spanning juz 1 (1–25) and juz 2 (26–40).
class FakeQuranApi extends ApiService {
  FakeQuranApi({this.offline = false});

  bool offline;
  final List<String> requests = [];

  static const baqarahVerses = 40;

  static Map<String, dynamic> surahJson(int n) => {
    'number': '$n',
    'name_id': n == 1 ? 'Al-Fatihah' : 'Al-Baqarah',
    'name_short': n == 1 ? 'الفاتحة' : 'البقرة',
    'translation_id': n == 1 ? 'Pembukaan' : 'Sapi',
    'revelation_id': n == 1 ? 'Makkiyyah' : 'Madaniyyah',
    'number_of_verses': n == 1 ? '7' : '$baqarahVerses',
    'audio_url': 'https://download.quranicaudio.com/quran/x/00$n.mp3',
    'tafsir': 'Tafsir $n',
  };

  static Map<String, dynamic> ayahJson(int surah, int ayah) => {
    'id': '${surah == 1 ? ayah : 7 + ayah}',
    'surah': '$surah',
    'ayah': '$ayah',
    'arab': surah == 2 && ayah == 1 ? 'الۤمّۤ ۚ' : 'آية $ayah',
    'latin': 'latin $surah:$ayah ',
    'text': 'arti $surah:$ayah',
    'juz': surah == 1 || ayah <= 25 ? '1' : '2',
    'page': '${surah == 1 ? 1 : 2 + ayah ~/ 10}',
  };

  static List<Surah> get surahs => [
    Surah.fromJson(surahJson(1)),
    Surah.fromJson(surahJson(2)),
  ];

  void _hit(String path) {
    requests.add(path);
    if (offline) throw Exception('SocketException: offline');
  }

  @override
  Future<List<Map<String, dynamic>>?> getAllSurat() async {
    _hit('quran/surat/semua');
    return [surahJson(1), surahJson(2)];
  }

  @override
  Future<List<Map<String, dynamic>>?> getAllJuz() async {
    _hit('quran/juz/semua');
    return [
      {
        'number': '1',
        'name': 'Juz 1',
        'surah_id_start': '1',
        'verse_start': '1',
        'surah_id_end': '2',
        'verse_end': '25',
        'name_start_id': 'Al-Fatihah',
        'name_end_id': 'Al-Baqarah',
        'ayat_arab': 'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
      },
      {
        'number': '2',
        'name': 'Juz 2',
        'surah_id_start': '2',
        'verse_start': '26',
        'surah_id_end': '2',
        'verse_end': '40',
        'name_start_id': 'Al-Baqarah',
        'name_end_id': 'Al-Baqarah',
        'ayat_arab': '۞ سَيَقُولُ السُّفَهَاءُ مِنَ النَّاسِ',
      },
    ];
  }

  @override
  Future<dynamic> getJson(String path) async {
    _hit(path);
    final range = RegExp(r'^quran/ayat/(\d+)/(\d+)-(\d+)$').firstMatch(path);
    if (range != null) {
      final surah = int.parse(range.group(1)!);
      return [
        for (
          var a = int.parse(range.group(2)!);
          a <= int.parse(range.group(3)!);
          a++
        )
          ayahJson(surah, a),
      ];
    }
    final juz = RegExp(r'^quran/ayat/juz/(\d+)$').firstMatch(path);
    if (juz != null) {
      final n = int.parse(juz.group(1)!);
      if (n == 1) {
        return [
          for (var a = 1; a <= 7; a++) ayahJson(1, a),
          for (var a = 1; a <= 25; a++) ayahJson(2, a),
        ];
      }
      if (n == 2) {
        return [for (var a = 26; a <= baqarahVerses; a++) ayahJson(2, a)];
      }
      return const [];
    }
    final page = RegExp(r'^quran/ayat/page/(\d+)$').firstMatch(path);
    if (page != null) {
      final n = int.parse(page.group(1)!);
      return [
        for (var a = 1; a <= 7; a++)
          if (ayahJson(1, a)['page'] == '$n') ayahJson(1, a),
        for (var a = 1; a <= baqarahVerses; a++)
          if (ayahJson(2, a)['page'] == '$n') ayahJson(2, a),
      ];
    }
    if (path == 'quran/tema/semua') return themes;
    final theme = RegExp(r'^quran/ayat/tema/(\d+)$').firstMatch(path);
    if (theme != null) {
      final id = int.parse(theme.group(1)!);
      return [
        for (final (surah, ayah) in themeAyat[id] ?? const <(int, int)>[])
          {...ayahJson(surah, ayah), 'theme': '$id'},
      ];
    }
    throw Exception('unexpected $path');
  }

  /// Other hosts (equran.id tafsir, alquran.cloud tajweed).
  @override
  Future<dynamic> getExternalJson(String url) async {
    _hit(url);
    final tafsir = RegExp(
      r'^https://equran\.id/api/v2/tafsir/(\d+)$',
    ).firstMatch(url);
    if (tafsir != null) {
      final surah = int.parse(tafsir.group(1)!);
      final verses = surah == 1 ? 7 : baqarahVerses;
      return {
        'code': 200,
        'message': 'Data retrieved successfully',
        'data': {
          'nomor': surah,
          'tafsir': [
            for (var a = 1; a <= verses; a++)
              {'ayat': a, 'teks': 'Tafsir Kemenag $surah:$a. Penjelasan ayat.'},
          ],
        },
      };
    }
    final tajweed = RegExp(
      r'^https://api\.alquran\.cloud/v1/surah/(\d+)/quran-tajweed$',
    ).firstMatch(url);
    if (tajweed != null) {
      final surah = int.parse(tajweed.group(1)!);
      final verses = surah == 1 ? 7 : baqarahVerses;
      return {
        'code': 200,
        'data': {
          'number': surah,
          'ayahs': [
            for (var a = 1; a <= verses; a++)
              {
                'numberInSurah': a,
                'text': a == 2
                    ? 'ذ[n[َٲ]لِكَ [h:11[ٱ]لْكِتَ[n[ـٰ]بُ'
                    : '[h:1[ٱ]لْحَمْدُ [q[د]',
              },
          ],
        },
      };
    }
    throw Exception('unexpected $url');
  }

  /// `quran/tema/semua`: three themes.
  static const themes = [
    {'id': '1', 'name': 'Tiga Golongan Manusia dalam Menyikapi Kebenaran'},
    {'id': '2', 'name': 'Perintah Beribadah kepada Allah'},
    {'id': '500', 'name': 'Hijrah untuk Membela Agama Allah'},
  ];

  /// `quran/ayat/tema/<id>`: (surah, ayah) per theme.
  static const themeAyat = {
    1: [(2, 1), (2, 2), (2, 3)],
    2: [(1, 5), (2, 21)],
    500: [(2, 26), (2, 27)],
  };
}
