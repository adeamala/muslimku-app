import 'package:flutter_test/flutter_test.dart';
import 'package:muslimku/features/quran/application/quran_progress_provider.dart';
import 'package:muslimku/features/quran/data/quran_repository.dart';
import 'package:muslimku/features/quran/domain/quran_models.dart';
import 'package:muslimku/features/quran/presentation/quran_list_logic.dart';

Surah _surah(
  int number,
  String name,
  String meaning,
  String revelation, {
  String arabic = '',
}) => Surah(
  number: number,
  name: name,
  arabicName: arabic,
  meaning: meaning,
  revelation: revelation,
  verseCount: 7,
);

final _surahs = [
  _surah(1, 'Al-Fatihah', 'Pembukaan', 'Makkiyyah', arabic: 'الفاتحة'),
  _surah(2, 'Al-Baqarah', 'Sapi', 'Madaniyyah', arabic: 'البقرة'),
  _surah(3, "Ali 'Imran", 'Keluarga Imran', 'Madaniyyah'),
  _surah(12, 'Yusuf', 'Yusuf', 'Makkiyyah'),
  _surah(36, 'Yasin', 'Yasin', 'Makkiyyah'),
  _surah(51, 'Az-Zariyat', 'Angin yang Menerbangkan', 'Makkiyyah'),
  _surah(73, 'Al-Muzzammil', 'Orang Yang Berselimut', 'Makkiyyah'),
  _surah(108, 'Al-Kausar', 'Pemberian Yang Banyak', 'Makkiyyah'),
];

List<int> _find(
  String query, [
  RevelationFilter filter = RevelationFilter.all,
]) => [
  for (final s in filterSurahs(_surahs, query: query, filter: filter)) s.number,
];

void main() {
  group('filterSurahs', () {
    test('an empty query keeps every surah in order', () {
      expect(_find(''), [1, 2, 3, 12, 36, 51, 73, 108]);
      expect(_find('   '), [1, 2, 3, 12, 36, 51, 73, 108]);
    });

    test('finds Al-Baqarah by name, spacing, number or meaning', () {
      for (final query in [
        'albaqarah',
        'al baqarah',
        'Al-Baqarah',
        'AL-BAQARAH',
        'baqarah',
        '2',
        'sapi',
        'SAPI',
      ]) {
        expect(_find(query), [2], reason: query);
      }
    });

    test('ignores apostrophes, hyphens and spaces', () {
      for (final query in [
        'ali imran',
        "ali'imran",
        'aliimran',
        "Ali 'Imran",
      ]) {
        expect(_find(query), [3], reason: query);
      }
      expect(_find('keluarga imran'), [3]);
    });

    test('a number finds only that surah', () {
      expect(_find('12'), [12]);
      expect(_find(' 36 '), [36]);
      expect(_find('036'), [36]);
      expect(_find('115'), isEmpty);
    });

    test('tolerates common spelling variants', () {
      expect(_find('yaasiin'), [36]);
      expect(_find('muzammil'), [73]);
      expect(_find('adz dzariyat'), [51]);
      expect(_find('kautsar'), [108]);
    });

    test('matches the Arabic name', () {
      expect(_find('البقرة'), [2]);
    });

    test('filters Makkiyyah and Madaniyyah', () {
      expect(_find('', RevelationFilter.makkiyyah), [1, 12, 36, 51, 73, 108]);
      expect(_find('', RevelationFilter.madaniyyah), [2, 3]);
      expect(_find('sapi', RevelationFilter.makkiyyah), isEmpty);
    });
  });

  group('khatamTicks', () {
    test('marks finished juz, the juz being read and the rest', () {
      final ticks = khatamTicks({1, 2, 30}, currentJuz: 22);
      expect(ticks, hasLength(30));
      expect(ticks[0], KhatamTick.done);
      expect(ticks[1], KhatamTick.done);
      expect(ticks[21], KhatamTick.current);
      expect(ticks[29], KhatamTick.done);
      expect(ticks.where((t) => t == KhatamTick.pending), hasLength(26));
    });

    test('nothing is current without a last read', () {
      expect(khatamTicks(const {}), everyElement(KhatamTick.pending));
      expect(
        khatamTicks(const {}, currentJuz: 0),
        everyElement(KhatamTick.pending),
      );
    });

    test('the juz being read stays current even when it was finished', () {
      expect(khatamTicks({22}, currentJuz: 22)[21], KhatamTick.current);
    });

    test('numbers outside 1-30 are ignored', () {
      final ticks = khatamTicks({0, 5, 31}, currentJuz: 40);
      expect(ticks.where((t) => t != KhatamTick.pending), hasLength(1));
      expect(khatamDoneCount({0, 1, 2, 31}), 2);
    });
  });

  group('last read labels', () {
    LastRead read({int juz = 22, int page = 441, int verses = 83}) => LastRead(
      surah: 36,
      ayah: 12,
      surahName: 'Yasin',
      verseCount: verses,
      juz: juz,
      page: page,
      updatedAt: DateTime(2026, 10, 25),
    );

    test('card subtitle shows ayah, juz and page', () {
      expect(lastReadDetail(read()), 'Ayat 12 dari 83 · Juz 22 · Hal. 441');
    });

    test('card subtitle leaves out what is unknown', () {
      expect(lastReadDetail(read(juz: 0, page: 0, verses: 0)), 'Ayat 12');
    });

    test('khatam line names the juz, surah and ayah', () {
      expect(readingNowLabel(read()), 'Juz 22 · Yasin ayat 12');
      expect(readingNowLabel(read(juz: 0)), 'Yasin ayat 12');
    });
  });

  group('formatSavedSize', () {
    test('megabytes with an Indonesian decimal comma', () {
      expect(formatSavedSize(4500000), '±4,5 MB');
      expect(formatSavedSize(4549999), '±4,5 MB');
      expect(formatSavedSize(6000000), '±6 MB');
      expect(formatSavedSize(12345678), '±12,3 MB');
    });

    test('small sizes in kilobytes, nothing as 0 MB', () {
      expect(formatSavedSize(40000), '±40 KB');
      expect(formatSavedSize(300), '±1 KB');
      expect(formatSavedSize(0), '0 MB');
    });
  });

  group('download card', () {
    test('offers start, resume, cancel or nothing', () {
      expect(
        downloadActionFor(const QuranDownloadState()),
        DownloadAction.start,
      );
      expect(
        downloadActionFor(const QuranDownloadState(storedSurahs: 86)),
        DownloadAction.resume,
      );
      expect(
        downloadActionFor(
          const QuranDownloadState(running: true, storedSurahs: 86),
        ),
        DownloadAction.cancel,
      );
      expect(
        downloadActionFor(const QuranDownloadState(storedSurahs: 114)),
        DownloadAction.none,
      );
      expect(
        [for (final a in DownloadAction.values) a.label],
        ['Unduh', 'Lanjutkan', 'Batal', ''],
      );
    });

    test('caption shows the saved size against the total', () {
      expect(
        downloadCaption(
          const QuranDownloadState(storedSurahs: 86, storedBytes: 4500000),
        ),
        '±4,5 MB dari ±6 MB',
      );
      expect(
        downloadCaption(
          const QuranDownloadState(
            running: true,
            doneJuz: 4,
            storedSurahs: 3,
            storedBytes: 900000,
          ),
        ),
        '±900 KB dari ±6 MB · juz 4/30',
      );
      expect(
        downloadCaption(const QuranDownloadState()),
        '±6 MB untuk 114 surat',
      );
      expect(
        downloadCaption(
          const QuranDownloadState(storedSurahs: 114, storedBytes: 5900000),
        ),
        'Semua surat tersimpan · ±5,9 MB',
      );
    });
  });

  test('juz range breaks after the dash', () {
    final juz = JuzInfo.fromJson(const {
      'number': '2',
      'surah_id_start': '2',
      'verse_start': '142',
      'surah_id_end': '2',
      'verse_end': '252',
      'name_start_id': 'Al-Baqarah',
      'name_end_id': 'Al-Baqarah',
      'ayat_arab': 'سَيَقُولُ السُّفَهَاءُ',
    });
    expect(juzRangeText(juz), 'Al-Baqarah 142 –\nAl-Baqarah 252');
  });
}
