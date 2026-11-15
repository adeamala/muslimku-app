import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muslimku/core/network/api_service.dart';
import 'package:muslimku/core/storage/local_store.dart';
import 'package:muslimku/core/theme/app_theme.dart';
import 'package:muslimku/features/quran/domain/quran_models.dart';
import 'package:muslimku/features/quran/presentation/quran_reader_screen.dart';
import 'package:muslimku/features/quran/presentation/quran_screen.dart';

import '../../../support/fake_quran_api.dart';

/// Pumps the Al-Qur'an tab at phone size (390x844) with [api], a memory store
/// and animations disabled (unless [animations]).
Future<void> pumpQuran(
  WidgetTester tester, {
  required FakeQuranApi api,
  MemoryLocalStore? store,
  double textScale = 1,
  bool animations = false,
}) async {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        apiServiceProvider.overrideWithValue(api),
        localStoreProvider.overrideWithValue(store ?? MemoryLocalStore()),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            disableAnimations: !animations,
            textScaler: TextScaler.linear(textScale),
          ),
          child: child!,
        ),
        home: const Scaffold(body: QuranScreen()),
      ),
    ),
  );
  await settle(tester);
}

Future<void> settle(WidgetTester tester, [int frames = 10]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// The reader that was opened last: (surah, ayah).
(int, int) openedReader(WidgetTester tester) {
  final reader = tester.widget<QuranReaderScreen>(
    find.byType(QuranReaderScreen),
  );
  return (reader.surahNumber, reader.initialAyah);
}

/// The fake surah list as saved by `ContentCache` [age] ago (older than 30
/// days means the app tries to refresh it first).
void saveSurahList(
  MemoryLocalStore store, {
  Duration age = const Duration(days: 40),
}) {
  store.values['quran/surah_list.json'] = jsonEncode({
    'savedAt': DateTime.now().subtract(age).toIso8601String(),
    'data': [FakeQuranApi.surahJson(1), FakeQuranApi.surahJson(2)],
  });
}

/// Al-Fatihah saved on the phone.
void saveFatihah(MemoryLocalStore store) {
  store.values['quran/surah_001.json'] = jsonEncode([
    for (var a = 1; a <= 7; a++)
      Ayah.fromJson(FakeQuranApi.ayahJson(1, a)).toJson(),
  ]);
}

String lastReadJson({
  int surah = 2,
  int ayah = 12,
  String name = 'Al-Baqarah',
  int verses = 40,
  int juz = 1,
  int page = 3,
}) => jsonEncode({
  'surah': surah,
  'ayah': ayah,
  'surahName': name,
  'verseCount': verses,
  'juz': juz,
  'page': page,
  'updatedAt': '2026-10-25T18:00:00.000',
});

String bookmarksJson(List<(int, int, String, String, String)> marks) =>
    jsonEncode([
      for (final (surah, ayah, name, snippet, savedAt) in marks)
        {
          'surah': surah,
          'ayah': ayah,
          'surahName': name,
          'snippet': snippet,
          'savedAt': savedAt,
        },
    ]);
