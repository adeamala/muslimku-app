import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:muslimku/core/network/api_service.dart';
import 'package:muslimku/core/storage/local_store.dart';
import 'package:muslimku/features/prayer/data/reminder_gateway.dart';
import 'package:muslimku/features/quran/application/quran_audio_provider.dart';
import 'package:muslimku/features/quran/data/murottal_store.dart';
import 'package:muslimku/features/quran/domain/quran_models.dart';
import 'package:muslimku/features/quran/domain/reciters.dart';
import 'package:muslimku/features/reading/application/reading_settings_provider.dart';
import 'package:muslimku/features/settings/presentation/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/fake_home_api.dart';
import '../../../support/fake_quran_api.dart';
import '../../../support/fake_quran_reader_api.dart';
import '../../settings/settings_adzan_test.dart' show FakeGateway;
import 'reader_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => initializeDateFormatting('id_ID', null));
  setUp(() => SharedPreferences.setMockInitialValues({}));

  final fatihah = FakeQuranApi.surahs.first;
  final ayat = [
    for (var a = 1; a <= 7; a++) Ayah.fromJson(FakeQuranApi.ayahJson(1, a)),
  ];

  test('each reciter has its CDN id and bitrate', () {
    expect(Reciter.values, hasLength(5));
    expect(Reciter.alafasy.label, 'Mishary Rashid Alafasy');
    expect(
      Reciter.alafasy.url(8),
      'https://cdn.islamic.network/quran/audio/128/ar.alafasy/8.mp3',
    );
    // Sudais is only published at 192 and 64 kbps on that CDN.
    expect(
      Reciter.sudais.url(1),
      'https://cdn.islamic.network/quran/audio/192/ar.abdurrahmaansudais/1.mp3',
    );
    expect(Reciter.byName('husary'), Reciter.husary);
    expect(Reciter.byName('nobody'), Reciter.alafasy);
    // The ayah keeps its default URL for the old call sites.
    expect(ayat.first.audioUrl, Reciter.alafasy.url(ayat.first.id));
    expect(
      ayat.first.audioUrlFor(Reciter.muaiqly),
      contains('ar.mahermuaiqly'),
    );
  });

  test('the reciter is saved with the reading settings', () async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final n = c.read(readingSettingsProvider.notifier);
    await n.ready;
    expect(c.read(readingSettingsProvider).reciter, Reciter.alafasy);
    n.setReciter(Reciter.husary);
    await Future<void>.delayed(Duration.zero);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(ReadingSettingsNotifier.reciterKey), 'husary');

    final again = ProviderContainer();
    addTearDown(again.dispose);
    await again.read(readingSettingsProvider.notifier).ready;
    expect(again.read(readingSettingsProvider).reciter, Reciter.husary);
    // "Atur ulang" goes back to Alafasy.
    again.read(readingSettingsProvider.notifier).reset();
    expect(again.read(readingSettingsProvider).reciter, Reciter.alafasy);
  });

  test('the player streams the chosen reciter, ayah by ayah', () async {
    final player = FakeMurottalPlayer();
    final c = ProviderContainer(
      overrides: [
        murottalPlayerFactoryProvider.overrideWithValue(() => player),
        murottalStoreProvider.overrideWithValue(MemoryMurottalStore()),
      ],
    );
    addTearDown(c.dispose);
    c.listen(quranAudioProvider, (_, _) {});
    await c.read(readingSettingsProvider.notifier).ready;
    c.read(readingSettingsProvider.notifier).setReciter(Reciter.sudais);
    final audio = c.read(quranAudioProvider.notifier);
    await audio.playSurah(fatihah, ayat, from: 1);
    expect(player.played, [Reciter.sudais.url(ayat[0].id)]);
    expect(c.read(quranAudioProvider).reciter, 'Abdurrahman As-Sudais');
    // Switching mid-surah takes effect from the next ayah.
    c.read(readingSettingsProvider.notifier).setReciter(Reciter.minshawi);
    player.complete();
    await Future<void>.delayed(Duration.zero);
    expect(player.played.last, Reciter.minshawi.url(ayat[1].id));
    expect(c.read(quranAudioProvider).reciter, 'Mohamed Siddiq Al-Minshawi');
  });

  testWidgets('Pengaturan > Tampilan picks the reciter', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiServiceProvider.overrideWithValue(FakeHomeApi()),
          localStoreProvider.overrideWithValue(MemoryLocalStore()),
          reminderGatewayProvider.overrideWithValue(FakeGateway()),
        ],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Qari murottal'), 200);
    await tester.pumpAndSettle();
    expect(find.text('Mishary Rashid Alafasy'), findsOneWidget);
    await tester.tap(find.text('Qari murottal'));
    await tester.pumpAndSettle();
    expect(find.text('Abdurrahman As-Sudais'), findsOneWidget);
    await tester.tap(find.text('Abdurrahman As-Sudais'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(195, 40));
    await tester.pumpAndSettle();
    expect(find.text('Abdurrahman As-Sudais'), findsOneWidget);
    expect(find.text('Mishary Rashid Alafasy'), findsNothing);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(ReadingSettingsNotifier.reciterKey), 'sudais');
  });

  testWidgets('the murottal bar opens the reciter sheet', (tester) async {
    final h = await pumpReader(tester);
    await tester.tap(find.text('Putar murottal'));
    await settleReader(tester);
    expect(find.text('Mishary Rashid Alafasy'), findsOneWidget);
    await tester.tap(
      find.bySemanticsLabel('Qari Mishary Rashid Alafasy, ganti'),
    );
    await settleReader(tester);
    expect(find.text('Qari murottal'), findsOneWidget);
    await tester.tap(find.text('Mahmoud Khalil Al-Husary'));
    await settleReader(tester);
    expect(h.container.read(readingSettingsProvider).reciter, Reciter.husary);
    await tester.tapAt(const Offset(195, 40));
    await settleReader(tester);
    expect(find.text('Qari murottal'), findsNothing);
    // The bar still names the qari of the ayah being played; the next ayah
    // will be Al-Husary.
    expect(find.text('Mishary Rashid Alafasy'), findsOneWidget);
    await closeReader(tester);
  });
}
