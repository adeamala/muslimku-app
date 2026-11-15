import 'package:flutter_test/flutter_test.dart';
import 'package:muslimku/features/hadith/application/hadits_providers.dart'
    show dailyArbainNumber;
import 'package:muslimku/features/hadith/domain/hadith_model.dart';
import 'package:muslimku/features/hadith/presentation/hadits_format.dart';

import 'arbain_samples.dart';

void main() {
  group('arbainCitation', () {
    test('reads the narrators of real Arbain texts', () {
      expect(arbainCitation(arbainSamples[1]!.indo), 'HR. Bukhari & Muslim');
      expect(arbainCitation(arbainSamples[2]!.indo), 'HR. Muslim');
      expect(arbainCitation(arbainSamples[16]!.indo), 'HR. Bukhari');
    });

    test(
      'takes the first (HR ...) and ignores the later "Diriwayatkan oleh"',
      () {
        expect(
          arbainCitation(
            'Teks. (HR. Muslim) Diriwayatkan oleh Imam al Bukhari (1) dan Muslim (2)',
          ),
          'HR. Muslim',
        );
      },
    );

    test('accepts square brackets and odd spellings', () {
      expect(arbainCitation(arbainSamples[6]!.indo), 'HR. Bukhari & Muslim');
      expect(
        arbainCitation('Teks. (HR. At Tirmdzi, dan dia berkata hasan shahih)'),
        'HR. Tirmidzi',
      );
    });

    test('falls back to the "diriwayatkan oleh" sentence', () {
      expect(arbainCitation(arbainSamples[12]!.indo), 'HR. Tirmidzi');
      // "Sebagian lafadznya terdapat dalam shahih Al Bukhari dan Muslim"
      // belongs to the next sentence.
      expect(arbainCitation(arbainSamples[33]!.indo), 'HR. Baihaqi');
    });

    test('names the collection when no narrator is found', () {
      expect(arbainCitation('Tanpa keterangan perawi.'), 'Arbain An-Nawawi');
      expect(arbainCitation(''), 'Arbain An-Nawawi');
    });
  });

  group('quoteExcerpt', () {
    test('joins a short first quote with the next one (Arbain 16)', () {
      expect(
        quoteExcerpt(arbainSamples[16]!.indo),
        '”Berilah aku nasihat.” Beliau … bersabda: ”Janganlah engkau marah.”',
      );
      expect(
        quoteExcerpt(
          'Ia berkata: ”Agama itu nasihat.” Kami bertanya: ”Untuk siapa?”',
        ),
        '”Agama itu nasihat.” Kami bertanya: ”Untuk siapa?”',
      );
    });

    test('takes the first quoted sentence', () {
      expect(
        quoteExcerpt(
          'Beliau bersabda: “Agama itu mudah, jangan dipersulit.” Lalu…',
        ),
        '”Agama itu mudah, jangan dipersulit.”',
      );
      expect(
        quoteExcerpt('Dari Abu Hurairah: "Air itu suci dan mensucikan."'),
        '”Air itu suci dan mensucikan.”',
      );
    });

    test('skips a quote that only introduces a nested one', () {
      expect(
        quoteExcerpt(
          'dia berkata: ”Rasulullah bersabda: ”Islam dibangun di atas lima dasar.” (HR. Muslim)',
        ),
        '”Islam dibangun di atas lima dasar.”',
      );
    });

    test('uses an unclosed quote up to the citation (Arbain 6)', () {
      final text = quoteExcerpt(arbainSamples[6]!.indo);
      expect(
        text,
        startsWith('”Sesungguhnya perkara yang halal itu telah jelas'),
      );
      expect(text, isNot(contains('HR.')));
      expect(text.length, lessThanOrEqualTo(161));
    });

    test('without quotes starts after "bersabda:" and cuts at a word', () {
      final long =
          'Dari Fulan, ia berkata: Rasulullah bersabda: ${'kata ' * 40}';
      final text = quoteExcerpt(long);
      expect(text, startsWith('kata kata'));
      expect(text, endsWith('kata…'));
      expect(text.length, lessThanOrEqualTo(111));
      expect(quoteExcerpt('Pendek saja.'), 'Pendek saja.');
    });
  });

  group('cleanHaditsTranslation', () {
    test('drops the "Hadis No. n" header and the carriage return', () {
      expect(
        cleanHaditsTranslation(
          "Hadis\u00a0No. 1   \r  Dari Abu Hurairah\u00a0Radliyallaahu 'anhu bersabda.",
        ),
        "Dari Abu Hurairah Radliyallaahu 'anhu bersabda.",
      );
      expect(
        cleanHaditsTranslation('Hadis No.\u00a012   \r  Dari Ibnu Umar.'),
        'Dari Ibnu Umar.',
      );
    });

    test('keeps texts without a header and removes html tags', () {
      expect(
        cleanHaditsTranslation('Telah menceritakan  kepada <b>kami</b>.'),
        'Telah menceritakan kepada kami.',
      );
      expect(
        cleanHaditsArabic('قَالَ <b>( كَلِمَتَانِ )</b>'),
        'قَالَ ( كَلِمَتَانِ )',
      );
    });
  });

  group('matchesArbainQuery', () {
    final no16 = HaditsEntry.arbain({
      'no': '16',
      'judul': 'Janganlah Engkau Marah',
      'arab': '',
      'indo': arbainSamples[16]!.indo,
    });

    test('matches the title, ignoring case', () {
      expect(matchesArbainQuery(no16, 'marah'), isTrue);
      expect(matchesArbainQuery(no16, '  ENGKAU '), isTrue);
      expect(matchesArbainQuery(no16, 'niat'), isFalse);
      expect(matchesArbainQuery(no16, ''), isTrue);
    });

    test('matches numbers from their first digits', () {
      expect(matchesArbainQuery(no16, '16'), isTrue);
      expect(matchesArbainQuery(no16, '1'), isTrue);
      expect(matchesArbainQuery(no16, 'No. 16'), isTrue);
      expect(matchesArbainQuery(no16, '6'), isFalse);
      expect(matchesArbainQuery(no16, '17'), isFalse);
    });
  });

  group('formatRibuan', () {
    test('uses Indonesian thousand dots', () {
      expect(formatRibuan(42), '42');
      expect(formatRibuan(1597), '1.597');
      expect(formatRibuan(6638), '6.638');
      expect(formatRibuan(38102), '38.102');
      expect(formatRibuan(1234567), '1.234.567');
    });
  });

  group('dailyArbainNumber', () {
    test('follows the day of the year and wraps around', () {
      expect(dailyArbainNumber(DateTime(2026, 1, 1)), 1);
      expect(dailyArbainNumber(DateTime(2026, 2, 11)), 42);
      expect(dailyArbainNumber(DateTime(2026, 2, 12)), 1);
      // 25 Oct 2026 is day 298: (298 - 1) % 42 + 1.
      expect(dailyArbainNumber(DateTime(2026, 10, 25, 18, 2)), 4);
      expect(dailyArbainNumber(DateTime(2026, 10, 25, 0, 1)), 4);
      expect(dailyArbainNumber(DateTime(2026, 10, 25), count: 10), 8);
    });
  });
}
