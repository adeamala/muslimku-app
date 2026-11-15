import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muslimku/features/quran/application/quran_audio_provider.dart';
import 'package:muslimku/features/quran/data/murottal_store.dart';
import 'package:muslimku/features/quran/domain/quran_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/fake_quran_api.dart';
import '../../../support/fake_quran_reader_api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final fatihah = FakeQuranApi.surahs.first;
  final ayat = [
    for (var a = 1; a <= 7; a++) Ayah.fromJson(FakeQuranApi.ayahJson(1, a)),
  ];
  String url(int ayah) => ayat[ayah - 1].audioUrl;

  late FakeMurottalPlayer player;
  late ProviderContainer container;
  late QuranAudioController audio;
  MurottalState state() => container.read(quranAudioProvider);

  setUp(() {
    // The controller asks readingSettingsProvider for the qari.
    SharedPreferences.setMockInitialValues({});
    player = FakeMurottalPlayer();
    container = ProviderContainer(
      overrides: [
        murottalPlayerFactoryProvider.overrideWithValue(() => player),
        murottalStoreProvider.overrideWithValue(MemoryMurottalStore()),
      ],
    );
    // Keep the auto-dispose provider alive like the reader does.
    container.listen(quranAudioProvider, (_, _) {});
    audio = container.read(quranAudioProvider.notifier);
  });
  tearDown(() => container.dispose());

  test('plays ayah by ayah and moves on when an ayah ends', () async {
    await audio.playSurah(fatihah, ayat, from: 3);
    expect(player.played, [url(3)]);
    expect(state().surah, 1);
    expect(state().ayah, 3);
    expect(state().playing, isTrue);
    expect(state().loading, isFalse);
    expect(state().surahName, 'Al-Fatihah');

    player.complete();
    await pumpEventQueue();
    expect(player.played, [url(3), url(4)]);
    expect(state().ayah, 4);
  });

  test('stops after the last ayah of the surah', () async {
    await audio.playSurah(fatihah, ayat, from: 7);
    player.complete();
    await pumpEventQueue();
    expect(state().active, isFalse);
    expect(state().playing, isFalse);
    expect(player.played, [url(7)]);
    expect(player.calls.last, 'stop');
  });

  test('pause, resume, next, previous and stop', () async {
    await audio.playSurah(fatihah, ayat);
    await audio.pause();
    expect(state().playing, isFalse);
    expect(state().ayah, 1, reason: 'paused keeps the ayah');
    player.complete(); // a late event while paused must not advance
    await pumpEventQueue();
    expect(state().ayah, 1);
    await audio.toggle();
    expect(state().playing, isTrue);
    expect(player.calls, containsAllInOrder(['pause', 'resume']));

    await audio.next();
    expect(state().ayah, 2);
    await audio.previous();
    await audio.previous();
    expect(state().ayah, 1, reason: 'previous on ayah 1 restarts it');
    expect(player.played.map(ayat.map((a) => a.audioUrl).toList().indexOf), [
      0,
      1,
      0,
      0,
    ]);

    await audio.playAyah(5);
    expect(state().ayah, 5);
    await audio.stop();
    expect(state().active, isFalse);
  });

  test('a load error stops and asks for internet', () async {
    player.failing = {url(2)};
    await audio.playSurah(fatihah, ayat);
    player.complete();
    await pumpEventQueue();
    expect(state().active, isFalse);
    expect(state().playing, isFalse);
    expect(state().message, QuranAudioController.offlineMessage);
    expect(QuranAudioController.offlineMessage, 'Audio butuh internet');

    audio.clearMessage();
    expect(state().message, isNull);
  });

  test('an error while playing also stops', () async {
    await audio.playSurah(fatihah, ayat);
    player.fail();
    await pumpEventQueue();
    expect(state().active, isFalse);
    expect(state().message, 'Audio butuh internet');
  });

  test('reports position and duration of the current ayah', () async {
    await audio.playSurah(fatihah, ayat);
    player.tick(const Duration(seconds: 1), const Duration(seconds: 4));
    await pumpEventQueue();
    expect(audio.progress.value.fraction, closeTo(0.25, 1e-9));
    await audio.next();
    expect(audio.progress.value.fraction, 0);
  });

  test('the player is created lazily and disposed with the provider', () {
    final fresh = FakeMurottalPlayer();
    var created = 0;
    final c = ProviderContainer(
      overrides: [
        murottalPlayerFactoryProvider.overrideWithValue(() {
          created++;
          return fresh;
        }),
        murottalStoreProvider.overrideWithValue(MemoryMurottalStore()),
      ],
    );
    final sub = c.listen(quranAudioProvider, (_, _) {});
    expect(created, 0, reason: 'no audio plugin until something is played');
    c.read(quranAudioProvider.notifier).playSurah(fatihah, ayat);
    expect(created, 1);
    sub.close();
    c.dispose();
    expect(fresh.disposed, isTrue);
  });
}
