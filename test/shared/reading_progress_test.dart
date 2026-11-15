import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muslimku/features/prayer/domain/prayer_time_model.dart';
import 'package:muslimku/features/quran/application/quran_progress_provider.dart';
import 'package:muslimku/features/reading/application/reading_settings_provider.dart';
import 'package:muslimku/shared/application/favorites_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('reading settings are clamped, saved and restored', () async {
    final first = ProviderContainer();
    addTearDown(first.dispose);
    final notifier = first.read(readingSettingsProvider.notifier);
    await notifier.ready;
    notifier
      ..setArabicSize(55)
      ..setShowLatin(false)
      ..setTheme(ReadingTheme.senja);
    expect(first.read(readingSettingsProvider).arabicSize, 40);
    await Future<void>.delayed(Duration.zero);

    final second = ProviderContainer();
    addTearDown(second.dispose);
    await second.read(readingSettingsProvider.notifier).ready;
    final restored = second.read(readingSettingsProvider);
    expect(restored.arabicSize, 40);
    expect(restored.showLatin, isFalse);
    expect(restored.theme, ReadingTheme.senja);
    expect(restored.autoNight, isTrue);
  });

  test('night is between Maghrib and Subuh', () {
    final schedule = PrayerSchedule.fromJson(const {
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
    });
    expect(isNightTime(DateTime(2026, 10, 25, 17, 28), schedule), isFalse);
    expect(isNightTime(DateTime(2026, 10, 25, 17, 29), schedule), isTrue);
    expect(isNightTime(DateTime(2026, 10, 25, 3, 0), schedule), isTrue);
    expect(isNightTime(DateTime(2026, 10, 25, 3, 49), schedule), isFalse);
    expect(isNightTime(DateTime(2026, 10, 25, 19), null), isTrue);
  });

  test(
    'last read, bookmarks, khatam and favourites survive a restart',
    () async {
      final first = ProviderContainer();
      addTearDown(first.dispose);
      await first.read(lastReadProvider.notifier).ready;
      await first
          .read(lastReadProvider.notifier)
          .save(
            LastRead(
              surah: 36,
              ayah: 12,
              surahName: 'Yasin',
              verseCount: 83,
              juz: 22,
              page: 441,
              updatedAt: DateTime(2026, 10, 25),
            ),
          );
      final marks = first.read(ayahBookmarksProvider.notifier);
      await marks.ready;
      final mark = AyahBookmark(
        surah: 67,
        ayah: 1,
        surahName: 'Al-Mulk',
        snippet: 'Mahaberkah Zat',
        savedAt: DateTime(2026, 10, 25),
      );
      expect(marks.toggle(mark), isTrue);
      expect(marks.contains(67, 1), isTrue);
      await first.read(khatamProvider.notifier).ready;
      first.read(khatamProvider.notifier)
        ..markDone(1)
        ..markDone(30)
        ..markDone(31);
      final doa = first.read(favoritesProvider('doa').notifier);
      await doa.ready;
      expect(doa.toggle('Doa Sebelum Makan'), isTrue);
      await Future<void>.delayed(Duration.zero);

      final second = ProviderContainer();
      addTearDown(second.dispose);
      await second.read(lastReadProvider.notifier).ready;
      await second.read(ayahBookmarksProvider.notifier).ready;
      await second.read(khatamProvider.notifier).ready;
      await second.read(favoritesProvider('doa').notifier).ready;
      final last = second.read(lastReadProvider)!;
      expect((last.surah, last.ayah, last.page), (36, 12, 441));
      expect(last.progress, closeTo(12 / 83, 1e-9));
      expect(second.read(ayahBookmarksProvider).single.key, '67:1');
      expect(second.read(khatamProvider), {1, 30});
      expect(second.read(favoritesProvider('doa')), {'Doa Sebelum Makan'});

      expect(second.read(ayahBookmarksProvider.notifier).toggle(mark), isFalse);
      expect(second.read(ayahBookmarksProvider), isEmpty);
    },
  );
}
