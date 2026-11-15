import 'package:flutter_test/flutter_test.dart';
import 'package:muslimku/features/quran/domain/quran_models.dart';
import 'package:muslimku/features/quran/presentation/reader/reader_scroll.dart';
import 'package:muslimku/features/quran/presentation/reader/reader_text.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

void main() {
  const syarh = Surah(
    number: 94,
    name: 'Asy-Syarh',
    arabicName: 'الشرح',
    meaning: 'Lapang',
    revelation: 'Makkiyyah',
    verseCount: 8,
  );
  final ayah5 = Ayah.fromJson(const {
    'id': '6095',
    'surah': '94',
    'ayah': '5',
    'arab': 'فَاِنَّ مَعَ الْعُسْرِ يُسْرًاۙ',
    'latin': "Fa'inna ma‘al-‘usri yusrā(n).",
    'text': 'Maka, sesungguhnya beserta kesulitan ada kemudahan.',
    'juz': '30',
    'page': '596',
  });

  group('share text', () {
    test('reference is "QS Name S:A"', () {
      expect(ayahReference(syarh, 5), 'QS Asy-Syarh 94:5');
    });

    test('Arabic, translation in quotes and the reference', () {
      expect(
        ayahShareText(syarh, ayah5),
        'فَاِنَّ مَعَ الْعُسْرِ يُسْرًاۙ\n\n'
        '“Maka, sesungguhnya beserta kesulitan ada kemudahan.”\n\n'
        'QS Asy-Syarh 94:5',
      );
      expect(
        ayahShareText(syarh, ayah5, translation: false),
        'فَاِنَّ مَعَ الْعُسْرِ يُسْرًاۙ\n\nQS Asy-Syarh 94:5',
      );
    });

    test('Kemenag footnote numbers are dropped', () {
      expect(cleanTranslation('Alif Lām Mīm.4)'), 'Alif Lām Mīm.');
      expect(
        cleanTranslation('kepada orang-orang yang mau mengikutinya638) dan'),
        'kepada orang-orang yang mau mengikutinya dan',
      );
      expect(
        cleanTranslation('“Masuklah ke surga.”640) Dia berkata'),
        '“Masuklah ke surga.” Dia berkata',
      );
      expect(
        cleanTranslation('(lihat QS al-Baqarah/2: 30) dan (1) hari'),
        '(lihat QS al-Baqarah/2: 30) dan (1) hari',
        reason: 'references and numbered lists stay',
      );
    });

    test('bookmark snippet is the start of the translation', () {
      final long = 'kata ' * 40;
      final snippet = bookmarkSnippet(long);
      expect(snippet.length, lessThanOrEqualTo(91));
      expect(snippet, endsWith('…'));
      expect(bookmarkSnippet('Yā Sīn.'), 'Yā Sīn.');
    });
  });

  group('visible ayat', () {
    // Item 0 is the surah header, items 1..N the ayat, N+1 the footer.
    ItemPosition at(int index, double lead, double trail) => ItemPosition(
      index: index,
      itemLeadingEdge: lead,
      itemTrailingEdge: trail,
    );

    test('the header counts as ayah 1', () {
      final view = visibleAyat(
        [at(0, 0, 0.6), at(1, 0.6, 0.9), at(2, 0.9, 1.2)],
        ayahCount: 10,
        top: 0.1,
      );
      expect(view.first, 1);
      expect(view.visible, [1, 2]);
    });

    test('items hidden under the app bar are skipped', () {
      final view = visibleAyat(
        [
          at(4, -0.3, 0.11),
          at(5, 0.11, 0.5),
          at(6, 0.5, 1.1),
          at(3, -0.8, -0.3),
        ],
        ayahCount: 10,
        top: 0.1,
      );
      expect(view.first, 5);
      expect(view.visible, [5, 6]);
    });

    test('the footer maps to the last ayah', () {
      final view = visibleAyat(
        [at(11, 0.2, 0.6), at(10, -0.2, 0.2)],
        ayahCount: 10,
        top: 0.1,
      );
      expect(view.first, 10);
      expect(view.visible, [10]);
    });

    test('nothing laid out yet', () {
      final view = visibleAyat(const [], ayahCount: 10);
      expect(view.first, isNull);
      expect(view.visible, isEmpty);
    });
  });
}
