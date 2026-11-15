import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muslimku/features/quran/application/quran_progress_provider.dart';
import 'package:muslimku/features/quran/application/quran_reader_progress.dart';
import 'package:muslimku/features/quran/domain/quran_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/fake_quran_api.dart';

void main() {
  final baqarah = FakeQuranApi.surahs[1];
  final ayat = [
    for (var a = 1; a <= FakeQuranApi.baqarahVerses; a++)
      Ayah.fromJson(FakeQuranApi.ayahJson(2, a)),
  ];
  final juz = [
    JuzInfo.fromJson(const {
      'number': '1',
      'surah_id_start': '1',
      'verse_start': '1',
      'surah_id_end': '2',
      'verse_end': '25',
    }),
    JuzInfo.fromJson(const {
      'number': '2',
      'surah_id_start': '2',
      'verse_start': '26',
      'surah_id_end': '2',
      'verse_end': '40',
    }),
  ];

  late ProviderContainer container;
  late List<LastRead> saved;
  late ReaderProgressTracker tracker;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    container = ProviderContainer();
    saved = [];
    tracker = ReaderProgressTracker(
      surah: baqarah,
      ayat: ayat,
      juz: juz,
      saveLastRead: (value) {
        saved.add(value);
        return container.read(lastReadProvider.notifier).save(value);
      },
      markJuzDone: container.read(khatamProvider.notifier).markDone,
      clock: () => DateTime(2026, 10, 25, 20),
    );
  });
  tearDown(() {
    tracker.dispose();
    container.dispose();
  });

  testWidgets('saves the first visible ayah once scrolling settles', (
    tester,
  ) async {
    tracker.update(3, const [3, 4, 5]);
    await tester.pump(const Duration(milliseconds: 600));
    tracker.update(7, const [7, 8]);
    await tester.pump(const Duration(milliseconds: 600));
    expect(saved, isEmpty, reason: 'still within one second of scrolling');
    tracker.update(30, const [30, 31]);
    await tester.pump(const Duration(seconds: 1));
    expect(saved.map((s) => s.ayah), [30]);

    final last = container.read(lastReadProvider)!;
    expect(last.surah, 2);
    expect(last.surahName, 'Al-Baqarah');
    expect(last.verseCount, 40);
    expect(last.juz, 2);
    expect(last.page, 5);
    expect(last.updatedAt, DateTime(2026, 10, 25, 20));

    tracker.update(30, const [30, 31]);
    await tester.pump(const Duration(seconds: 2));
    expect(saved, hasLength(1), reason: 'same ayah is not saved twice');
  });

  testWidgets('leaving the reader saves right away', (tester) async {
    tracker.update(12, const [12, 13]);
    tracker.flush();
    expect(saved.map((s) => s.ayah), [12]);
    await tester.pump(const Duration(seconds: 2));
    expect(saved, hasLength(1));
  });

  testWidgets('marks a juz as read when its last ayah shows', (tester) async {
    tracker.update(20, const [20, 21, 22, 23, 24]);
    expect(container.read(khatamProvider), isEmpty);
    tracker.update(22, const [22, 23, 24, 25, 26]);
    expect(container.read(khatamProvider), {1});
    tracker.update(38, const [38, 39, 40]);
    expect(container.read(khatamProvider), {1, 2});
    tracker.dispose();
  });

  testWidgets('juz arriving later still count', (tester) async {
    final early = ReaderProgressTracker(
      surah: baqarah,
      ayat: ayat,
      saveLastRead: (_) async {},
      markJuzDone: container.read(khatamProvider.notifier).markDone,
    );
    early.update(25, const [25]);
    expect(container.read(khatamProvider), isEmpty);
    early.juz = juz;
    early.update(25, const [25]);
    expect(container.read(khatamProvider), {1});
    early.dispose();
  });

  testWidgets('"Tandai terakhir dibaca" wins over scrolling', (tester) async {
    tracker.update(5, const [5]);
    await tracker.markLastRead(9);
    expect(container.read(lastReadProvider)!.ayah, 9);
    tracker.update(15, const [15]);
    await tester.pump(const Duration(seconds: 2));
    tracker.flush();
    expect(saved.map((s) => s.ayah), [9]);
  });
}
