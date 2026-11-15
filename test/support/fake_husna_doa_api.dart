import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muslimku/core/network/api_service.dart';
import 'package:muslimku/core/storage/local_store.dart';
import 'package:muslimku/core/theme/app_theme.dart';
import 'package:muslimku/core/time/clock_provider.dart';

/// MyQuran stand-in for the Asmaul Husna and Doa tabs, shaped like
/// `husna/semua` and `doa/semua` (doa text in `doa`/`artinya`, `id` "",
/// a title and meanings with stray `\r\n`, a waqf mark after a space).
class FakeHusnaDoaApi extends ApiService {
  FakeHusnaDoaApi({this.offline = false});

  bool offline;
  int husnaCalls = 0;
  int doaCalls = 0;

  /// Names 1–12 and 83 (83 shares its meaning with 1).
  static const husna = <Map<String, Object>>[
    {
      'id': 1,
      'arab': 'الرَّحْمـٰنُ',
      'latin': 'Ar-Rahmânu',
      'indo': 'Yang Maha Pengasih',
    },
    {
      'id': 2,
      'arab': 'الرَّحِيْمُ',
      'latin': 'Ar-Raḫîmu',
      'indo': 'Yang Maha Penyayang',
    },
    {
      'id': 3,
      'arab': 'الْمَلِكُ',
      'latin': 'Al-Maliku',
      'indo': 'Yang Maha Merajai/Memerintah',
    },
    {
      'id': 4,
      'arab': 'الْقُدُّوْسُ',
      'latin': 'Al-Quddûsu',
      'indo': 'Yang Mahasuci',
    },
    {
      'id': 5,
      'arab': 'السَّلاَمُ',
      'latin': 'As-Salâmu',
      'indo': 'Yang Maha Memberi Kesejahteraan',
    },
    {
      'id': 6,
      'arab': 'الْمُؤْمِنُ',
      'latin': 'Al-Mu’minu',
      'indo': 'Yang Maha Memberi Keamanan',
    },
    {
      'id': 7,
      'arab': 'الْمُهَيْمِنُ',
      'latin': 'Al-Muhaiminu',
      'indo': 'Yang Maha Pemelihara',
    },
    {
      'id': 8,
      'arab': 'الْعَزِيْزُ',
      'latin': 'Al-`Azizu',
      'indo': 'Yang Memiliki Mutlak Kegagahan',
    },
    {
      'id': 9,
      'arab': 'الْجَبَّارُ',
      'latin': 'Al-Jabbâru',
      'indo': 'Yang Maha Perkasa',
    },
    {
      'id': 10,
      'arab': 'الْمُتَكَبِّرُ',
      'latin': 'Al-Mutakabbiru',
      'indo': 'Yang Maha Megah',
    },
    {
      'id': 11,
      'arab': 'الْخَالِقُ',
      'latin': 'Al-Khâliqu',
      'indo': 'Yang Maha Pencipta',
    },
    {
      'id': 12,
      'arab': 'الْبَارِئُ',
      'latin': 'Al-Bâri’u',
      'indo': 'Yang Maha Melepaskan',
    },
    {
      'id': 83,
      'arab': 'الرَّؤُوْفُ',
      'latin': 'Ar-Ra’ûfu',
      'indo': 'Yang Maha Pengasih',
    },
  ];

  /// 11 doa in MyQuran order: Al-Qur'an 3, Hadits 1, Harian 5, Haji 2.
  static const doa = <Map<String, Object>>[
    {
      'id': '',
      'doa':
          'رَبَّنَا آتِنَا فِي الدُّنْيَا حَسَنَةً وَفِي الْآخِرَةِ حَسَنَةً وَقِنَا عَذَابَ النَّارِ',
      'ayat': '',
      'latin': '',
      'artinya':
          'Ya Tuhan kami, berilah kami kebaikan di dunia dan kebaikan di akhirat, dan lindungilah kami dari azab neraka.',
      'judul': 'Doa Mohon Kebaikan Dunia dan Akhirat',
      'source': 'quran',
    },
    {
      'id': '',
      'doa':
          'رَبَّنَا لَا تُزِغْ قُلُوبَنَا بَعْدَ إِذْ هَدَيْتَنَا وَهَبْ لَنَا مِنْ لَدُنْكَ رَحْمَةً ۚ إِنَّكَ أَنْتَ الْوَهَّابُ',
      'ayat': '',
      'latin': '',
      'artinya':
          'Ya Tuhan, janganlah Engkau jadikan hati kami condong kepada kesesatan sesudah Engkau berikan petunjuk kepada kami.',
      'judul': 'Doa Diberi Keteguhan Iman',
      'source': 'quran',
    },
    {
      'id': '',
      'doa':
          'لَا إِلَهَ إِلَّا أَنْتَ سُبْحَانَكَ إِنِّي كُنْتُ مِنَ الظَّالِمِينَ',
      'ayat': '',
      'latin': '',
      'artinya':
          'Tidak ada tuhan selain Engkau, Maha Suci Engkau. Sungguh, aku termasuk orang-orang yang zalim.',
      'judul': 'Doa Agar Terlepas dari Kesulitan / Istigfar \r\nNabi Yunus',
      'source': 'quran',
    },
    {
      'id': '',
      'doa':
          'اَللَّهُمَّ اِغْفِرْ لِي مَا قَدَّمْتُ وَمَا أَخَّرْتُ وَمَا أَسْرَرْتُ وَمَا أَعْلَنْتُ',
      'ayat': '',
      'latin': '',
      'artinya':
          'Ya Allah, ampunilah kesalahan, \r\nkebodohan dan keterlaluanku dalam segala \r\nurusan, kepada-\r\nMu aku kembali.',
      'judul': 'Doa Mohon Ampunan Dosa',
      'source': 'hadits',
    },
    {
      'id': '',
      'doa': 'اَللّٰهُمَّ كَمَا حَسَّـنْتَ خَلْقِـيْ فَحَسِّـنْ خُلُقِـيْ',
      'ayat': '',
      'latin': '',
      'artinya':
          'Ya Allah sebagaimana Engkau telah ciptakan aku dengan baik, maka perbaikilah akhlakku.',
      'judul': 'Doa Ketika Bercermin',
      'source': 'harian',
    },
    {
      'id': '',
      'doa': 'اللَّهُمَّ بارِكْ لَنا فِيما رَزَقْتَنا وَقِنا عَذَابَ النَّارِ',
      'ayat': '',
      'latin': '',
      'artinya':
          'Ya Allah berkatilah rezeki yang telah kau limpahkan pada kami, dan peliharalah kami dari azab api neraka.',
      'judul': 'Doa Sebelum Makan',
      'source': 'harian',
    },
    {
      'id': '',
      'doa':
          'اَلْحَمْدُ ِللهِ الَّذِيْنَ اَطْعَمَنَا وَسَقَانَا وَجَعَلَنَا مِنَ الْمُسْلِمِيْنَ',
      'ayat': '',
      'latin': '',
      'artinya':
          'Segala puji bagi Allah yang telah memberi kami makan dan minum serta menjadikan kami termasuk golongan orang muslim.',
      'judul': 'Doa Sesudah Makan',
      'source': 'harian',
    },
    {
      'id': '',
      'doa': 'بِاسْمِكَ اللهُمَّ أَحْيَا وَأَمُوْتُ',
      'ayat': '',
      'latin': '',
      'artinya':
          'Dengan menyebut nama-Mu, Ya Allah, aku hidup dan dengan menyebut nama-Mu aku mati.',
      'judul': 'Doa Sebelum Tidur',
      'source': 'harian',
    },
    {
      'id': '',
      'doa':
          'بِسْمِ اللهِ تَوَكَّلْتُ عَلَى اللهِ، لَا حَوْلَ وَلَا قُوَّةَ إِلَّا بِاللهِ',
      'ayat': '',
      'latin': '',
      'artinya':
          'Dengan nama Allah, aku bertawakkal kepada Allah. Tiada daya dan kekuatan kecuali dengan Allah.',
      'judul': 'Doa Keluar Rumah',
      'source': 'harian',
    },
    {
      'id': '',
      'doa':
          'اَللّٰهُمَّ هٰذَا حَرَمُكَ وَأَمْنُكَ فَحَرِّمْ لَحْمِيْ وَدَمِيْ وَشَعْرِيْ وَبَشَرِيْ عَلَى النَّارِ',
      'ayat': '',
      'latin': '',
      'artinya':
          'Ya Allah kota ini adalah tanah Haram-Mu dan tempat yang aman, maka hindarkanlah daging, darah, rambut, bulu dan kulitku dari neraka.',
      'judul': 'Doa Masuk kota Mekkah',
      'source': 'haji',
    },
    {
      'id': '',
      'doa':
          'اَللّٰهُمَّ أَنْتَ السَّلَامُ وَمِنْكَ السَّلَامُ فَحَيِّنَا رَبَّنَا بِالسَّلَامِ',
      'ayat': '',
      'latin': '',
      'artinya':
          'Ya Allah, Engkau sumber keselamatan dan dari-Mulah datangnya keselamatan, hidupkanlah kami wahai Tuhan kami dengan keselamatan.',
      'judul': 'Doa Masuk Masjidil Haram',
      'source': 'haji',
    },
  ];

  @override
  Future<List<Map<String, dynamic>>> getAllAsmaulHusna() async {
    husnaCalls++;
    if (offline) throw Exception('SocketException: offline');
    return [for (final h in husna) Map<String, dynamic>.of(h)];
  }

  @override
  Future<List<Map<String, dynamic>>> getAllDoa() async {
    doaCalls++;
    if (offline) throw Exception('SocketException: offline');
    return [for (final d in doa) Map<String, dynamic>.of(d)];
  }
}

/// Pumps [child] at phone size (390x844) with [api], an in-memory store,
/// 18:02 on 25 Oct 2026 and animations disabled. [textScale] tests large text.
Future<void> pumpSenja(
  WidgetTester tester,
  Widget child, {
  required FakeHusnaDoaApi api,
  LocalStore? store,
  List<Override> overrides = const [],
  double textScale = 1,
}) async {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        apiServiceProvider.overrideWithValue(api),
        localStoreProvider.overrideWithValue(store ?? MemoryLocalStore()),
        clockProvider.overrideWith(
          (ref) => Stream.value(DateTime(2026, 10, 25, 18, 2)),
        ),
        ...overrides,
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            disableAnimations: true,
            textScaler: TextScaler.linear(textScale),
          ),
          child: child!,
        ),
        home: child,
      ),
    ),
  );
  await settleSenja(tester);
}

Future<void> settleSenja(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}
