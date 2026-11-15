import 'package:muslimku/core/network/api_service.dart';
import 'package:muslimku/features/prayer/domain/prayer_time_model.dart';

import 'fake_hadits_api.dart';

/// Offline stand-in for MyQuran with the data of Kota Kediri, 25 Oct 2026.
class FakeHomeApi extends ApiService {
  FakeHomeApi({this.failPrayerTimes = false, this.failArbainList = false});

  bool failPrayerTimes;

  /// `hadits/arbain/semua` fails, as on a first start without internet.
  bool failArbainList;
  int arbainListCalls = 0;
  int prayerCalls = 0;
  final List<String> prayerCities = [];

  static const jadwalJson = <String, dynamic>{
    'id': '1632',
    'lokasi': 'KOTA KEDIRI',
    'daerah': 'JAWA TIMUR',
    'jadwal': {
      'tanggal': 'Minggu, 25/10/2026',
      'imsak': '03:39',
      'subuh': '03:49',
      'terbit': '05:03',
      'dhuha': '05:30',
      'dzuhur': '11:20',
      'ashar': '14:29',
      'maghrib': '17:29',
      'isya': '18:40',
      'date': '2026-10-25',
    },
  };

  static final jadwal = PrayerTimeModel.fromJson(jadwalJson);

  @override
  Future<Map<String, dynamic>?> getPrayerTimes(
    String cityId,
    String date,
  ) async {
    prayerCalls++;
    prayerCities.add(cityId);
    if (failPrayerTimes) throw Exception('offline');
    return jadwalJson;
  }

  @override
  Future<Map<String, dynamic>?> getRandomQuranAyah() async => {
    'ayat': {
      'ayah': '28',
      'arab':
          'الَّذِيْنَ اٰمَنُوْا وَتَطْمَىِٕنُّ قُلُوْبُهُمْ بِذِكْرِ اللّٰهِ',
      'text':
          'Orang-orang yang beriman dan hati mereka menjadi tenteram dengan mengingat Allah.',
    },
    'info': {
      'surat': {
        'id': 13,
        'nama': {'ar': 'الرعد', 'id': "Ar-Ra'd"},
        'jumlah_ayat': 43,
      },
    },
  };

  @override
  Future<Map<String, dynamic>?> getRandomHadithArbain() async => {
    'nomor': 10,
    'arab': 'عَنْ أَبِيْ هُرَيْرَةَ',
    'indo': 'Dari Abu Hurairah radhiyallahu anhu.',
    'judul': 'Allah Mahabaik dan Hanya Menerima yang Baik',
  };

  /// The 42 Arbain hadiths; on 25 Oct "Hadits hari ini" is No. 4.
  @override
  Future<List<Map<String, dynamic>>> getAllHadithArbain() async {
    arbainListCalls++;
    if (failArbainList) throw Exception('offline');
    return [for (var n = 1; n <= 42; n++) FakeHaditsApi.arbainJson(n)];
  }

  @override
  Future<Map<String, dynamic>?> getRandomHadithBulughulMaram() async => {
    'no': 120,
    'ar': 'عَنْ',
    'indo': 'Dari Ibnu Umar.',
    'kitab': 'Bulughul Maram',
    'slug': 'bm',
  };

  @override
  Future<Map<String, dynamic>?> getRandomHadithPerawi() async => null;

  @override
  Future<Map<String, dynamic>?> getRandomAsmaulHusna() async => {
    'id': 66,
    'arab': 'الْوَاحِدُ',
    'latin': 'Al-Wâḫidu',
    'indo': 'Yang Maha Tunggal',
  };

  @override
  Future<Map<String, dynamic>?> getRandomDoa() async => {
    'id': 0,
    'arab': 'رَبَّنَا آتِنَا فِي الدُّنْيَا حَسَنَةً',
    'indo': 'Ya Tuhan kami, berilah kami kebaikan di dunia.',
    'judul': 'Doa Mohon Kebaikan Dunia dan Akhirat',
    'source': 'quran',
  };

  int suratListCalls = 0;

  @override
  Future<List<Map<String, dynamic>>?> getAllSurat() async {
    suratListCalls++;
    return null;
  }

  @override
  Future<List<Map<String, dynamic>>?> getAllJuz() async => null;

  @override
  Future<List<Map<String, dynamic>>?> searchCities(String keyword) async => [
    {'id': '1301', 'lokasi': 'KOTA JAKARTA'},
  ];

  final List<String> jsonPaths = [];

  /// Monthly schedule (every day = the 25 Oct times); any other path fails,
  /// so widget tests never reach the network.
  @override
  Future<dynamic> getJson(String path) async {
    jsonPaths.add(path);
    final month = RegExp(
      r'^sholat/jadwal/(\d+)/(\d{4})/(\d{2})$',
    ).firstMatch(path);
    if (month != null && !failPrayerTimes) {
      final year = int.parse(month.group(2)!);
      final m = int.parse(month.group(3)!);
      final days = DateTime(year, m + 1, 0).day;
      final base = jadwal.jadwal.toJson();
      return {
        'id': month.group(1),
        'lokasi': 'KOTA KEDIRI',
        'daerah': 'JAWA TIMUR',
        'jadwal': [
          for (var d = 1; d <= days; d++)
            {
              ...base,
              'date': '$year-${month.group(3)}-${d.toString().padLeft(2, '0')}',
            },
        ],
      };
    }
    throw Exception('offline: $path');
  }
}
