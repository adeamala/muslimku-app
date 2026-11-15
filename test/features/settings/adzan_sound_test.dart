import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:muslimku/core/network/api_service.dart';
import 'package:muslimku/core/storage/local_store.dart';
import 'package:muslimku/features/hadith/application/hadits_providers.dart';
import 'package:muslimku/features/prayer/application/adzan_provider.dart';
import 'package:muslimku/features/prayer/data/reminder_gateway.dart';
import 'package:muslimku/features/prayer/domain/adzan_plan.dart';
import 'package:muslimku/features/prayer/domain/prayer_time_model.dart';
import 'package:muslimku/features/quran/application/quran_audio_provider.dart';
import 'package:muslimku/features/settings/presentation/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_home_api.dart';
import '../../support/fake_quran_reader_api.dart' show FakeMurottalPlayer;
import 'settings_adzan_test.dart' show FakeGateway;

PrayerSchedule day(String date) => PrayerSchedule.fromJson({
  ...FakeHomeApi.jadwal.jadwal.toJson(),
  'date': date,
});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => initializeDateFormatting('id_ID', null));
  setUp(() => SharedPreferences.setMockInitialValues({}));

  final days = [day('2026-10-25'), day('2026-10-26')];
  final midnight = DateTime(2026, 10, 25, 0, 0);

  group('AdzanSound', () {
    test('has one notification channel per sound', () {
      // The old channel keeps its id, so phones that already set it up keep
      // their settings.
      expect(AdzanSound.bawaan.channelId, 'adzan');
      expect(AdzanSound.bedug.channelId, 'adzan_bedug');
      expect(AdzanSound.values.map((s) => s.channelId).toSet(), hasLength(7));
      expect(AdzanSound.bawaan.resource, isNull);
      expect(AdzanSound.senyap.resource, isNull);
      expect(AdzanSound.adzan.resource, 'adzan_penuh');
      // The full adzan previews with its first phrase.
      expect(AdzanSound.adzan.preview, 'adzan_takbir');
      for (final sound in AdzanSound.values) {
        expect(sound.label, isNotEmpty);
        expect(sound.description, isNotEmpty);
      }
    });

    test('every preview sound is bundled', () async {
      for (final sound in AdzanSound.values) {
        final preview = sound.preview;
        if (preview == null) continue;
        final bytes = await rootBundle.load('assets/sounds/$preview.ogg');
        expect(bytes.lengthInBytes, greaterThan(1000), reason: preview);
      }
    });

    test('the Android channel carries the sound', () {
      final bedug = LocalReminderGateway.channelFor(AdzanSound.bedug);
      expect(bedug.channelId, 'adzan_bedug');
      expect(bedug.channelName, 'Pengingat adzan · Bedug');
      expect(bedug.sound, isA<RawResourceAndroidNotificationSound>());
      expect(
        (bedug.sound! as RawResourceAndroidNotificationSound).sound,
        'adzan_bedug',
      );
      expect(bedug.playSound, isTrue);
      expect(bedug.importance, Importance.high);

      final silent = LocalReminderGateway.channelFor(AdzanSound.senyap);
      expect(silent.playSound, isFalse);
      expect(silent.sound, isNull);

      final system = LocalReminderGateway.channelFor(AdzanSound.bawaan);
      expect(system.channelId, 'adzan');
      expect(system.sound, isNull);
      expect(system.playSound, isTrue);
    });
  });

  group('AdzanPlan with sound, sahur and the daily hadith', () {
    test('prayer-time reminders carry the chosen sound, early ones do not', () {
      final plan = AdzanPlan.build(
        days: days,
        settings: const AdzanSettings(enabled: true, sound: AdzanSound.bedug),
        now: midnight,
        city: 'Kota Kediri',
      );
      final prayers = plan.where((r) => r.prayer != null && !r.early);
      expect(prayers, isNotEmpty);
      expect(prayers.every((r) => r.sound == AdzanSound.bedug), isTrue);
      final early = plan.where((r) => r.early);
      expect(early, isNotEmpty);
      expect(early.every((r) => r.sound == AdzanSound.bawaan), isTrue);
    });

    test('sahur reminder comes 45 minutes before Imsak with its own id', () {
      final plan = AdzanPlan.build(
        days: days,
        settings: const AdzanSettings(
          enabled: true,
          prayers: {AdzanPrayer.subuh},
          remindBefore: false,
          sahur: true,
          sound: AdzanSound.kentongan,
        ),
        now: midnight,
        city: 'Kota Kediri',
      );
      final sahur = plan.where((r) => r.sahur).toList();
      expect(sahur, hasLength(2));
      // Imsak 03:39 - 45 min.
      expect(sahur.first.at, DateTime(2026, 10, 25, 2, 54));
      expect(sahur.first.title, 'Waktunya sahur');
      expect(sahur.first.body, 'Imsak pukul 03:39 · Kota Kediri');
      expect(sahur.first.prayer, isNull);
      expect(sahur.first.sound, AdzanSound.kentongan);
      expect(sahur.first.id, AdzanPlan.sahurIdFor(DateTime(2026, 10, 25)));
      expect(plan.map((r) => r.id).toSet(), hasLength(plan.length));
      // Ids stay inside a 32-bit int for Android.
      expect(plan.every((r) => r.id > 0 && r.id < 2147483647), isTrue);
      // Sahur comes first in the day.
      expect(plan.first.sahur, isTrue);
      expect(plan[1].title, 'Waktunya Subuh');
    });

    test('sahur is off by default and skipped without an Imsak time', () {
      final plain = AdzanPlan.build(
        days: days,
        settings: const AdzanSettings(enabled: true),
        now: midnight,
        city: 'x',
      );
      expect(plain.where((r) => r.sahur), isEmpty);
      final noImsak = AdzanPlan.build(
        days: [
          PrayerSchedule.fromJson({
            ...FakeHomeApi.jadwal.jadwal.toJson(),
            'date': '2026-10-25',
            'imsak': '',
          }),
        ],
        settings: const AdzanSettings(enabled: true, sahur: true),
        now: midnight,
        city: 'x',
      );
      expect(noImsak.where((r) => r.sahur), isEmpty);
    });

    test('the first prayer of each day carries the hadith of the day', () {
      final plan = AdzanPlan.build(
        days: days,
        settings: const AdzanSettings(enabled: true, sahur: true),
        now: midnight,
        city: 'Kota Kediri',
        hadithFor: (date) => 'Hadits hari ini: No. ${date.day}',
      );
      final noted = plan.where((r) => r.note != null).toList();
      expect(noted, hasLength(2));
      expect(noted.first.title, 'Waktunya Subuh');
      expect(noted.first.note, 'Hadits hari ini: No. 25');
      expect(noted.last.note, 'Hadits hari ini: No. 26');
      // Not on the sahur, early or other prayer reminders.
      expect(
        plan.where((r) => r.sahur || r.early).every((r) => r.note == null),
        isTrue,
      );
      expect(
        plan.where((r) => r.prayer == AdzanPrayer.dzuhur && r.note != null),
        isEmpty,
      );
    });

    test('the hadith line names today\'s Arbain', () {
      final line = adzanHadithLine(
        DateTime(2026, 11, 6),
        titles: const {16: 'Janganlah Engkau Marah', 4: 'Takdir'},
        count: 42,
      );
      // 6 Nov is day 310 of the year: (309 % 42) + 1 = No. 16.
      expect(line, 'Hadits hari ini: Janganlah Engkau Marah (Arbain No. 16)');
      expect(
        adzanHadithLine(DateTime(2026, 11, 6), titles: const {}, count: 42),
        isNull,
      );
    });
  });

  ProviderContainer container({
    FakeGateway? gateway,
    FakeHomeApi? api,
    MurottalPlayer Function()? player,
  }) {
    final c = ProviderContainer(
      overrides: [
        apiServiceProvider.overrideWithValue(api ?? FakeHomeApi()),
        localStoreProvider.overrideWithValue(MemoryLocalStore()),
        reminderGatewayProvider.overrideWithValue(gateway ?? FakeGateway()),
        if (player != null)
          murottalPlayerFactoryProvider.overrideWithValue(player),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('the sound and sahur choices are saved and replanned', () async {
    final gateway = FakeGateway();
    final c = container(gateway: gateway);
    final adzan = c.read(adzanProvider.notifier);
    await adzan.ready;
    await adzan.setEnabled(true);
    expect(
      gateway.scheduled
          .where((r) => r.prayer != null && !r.early)
          .every((r) => r.sound == AdzanSound.bawaan),
      isTrue,
    );
    await adzan.setSound(AdzanSound.takbir);
    expect(c.read(adzanProvider).settings.sound, AdzanSound.takbir);
    expect(
      gateway.scheduled
          .where((r) => r.prayer != null && !r.early)
          .every((r) => r.sound == AdzanSound.takbir),
      isTrue,
    );
    expect(gateway.scheduled.where((r) => r.sahur), isEmpty);
    await adzan.setSahur(true);
    expect(gateway.scheduled.where((r) => r.sahur), isNotEmpty);
    // The sahur reminders count as reminders in Pengaturan.
    expect(
      c.read(adzanProvider).scheduled,
      gateway.scheduled.where((r) => !r.renewal).length,
    );
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(AdzanNotifier.soundKey), 'takbir');
    expect(prefs.getBool(AdzanNotifier.sahurKey), isTrue);

    // A new start reads them back.
    final again = container(gateway: FakeGateway());
    await again.read(adzanProvider.notifier).ready;
    expect(again.read(adzanProvider).settings.sound, AdzanSound.takbir);
    expect(again.read(adzanProvider).settings.sahur, isTrue);
  });

  test('reminders carry today\'s Arbain once the list is saved', () async {
    final gateway = FakeGateway();
    final c = container(gateway: gateway);
    final adzan = c.read(adzanProvider.notifier);
    await adzan.ready;
    await adzan.setEnabled(true);
    // Nothing saved yet: no hadith line, no request made for it.
    expect(gateway.scheduled.every((r) => r.note == null), isTrue);

    await c.read(arbainListProvider.future);
    await adzan.reschedule();
    final noted = gateway.scheduled.where((r) => r.note != null).toList();
    expect(noted, isNotEmpty);
    expect(noted.first.note, startsWith('Hadits hari ini: '));
    expect(noted.first.note, contains('(Arbain No. '));
    // One per day.
    expect(noted.map((r) => r.at.day).toSet().length, noted.length);
  });

  testWidgets('Pengaturan offers the sound and sahur options', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final player = FakeMurottalPlayer();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiServiceProvider.overrideWithValue(FakeHomeApi()),
          localStoreProvider.overrideWithValue(MemoryLocalStore()),
          reminderGatewayProvider.overrideWithValue(FakeGateway()),
          murottalPlayerFactoryProvider.overrideWithValue(() => player),
        ],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Pengingat adzan'), 200);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Suara pengingat'), 100);
    await tester.pumpAndSettle();
    expect(find.text('Suara pengingat'), findsOneWidget);
    expect(find.textContaining('Bunyi notifikasi HP'), findsOneWidget);
    expect(find.text('Pengingat sahur'), findsOneWidget);

    await tester.tap(find.text('Suara pengingat'));
    await tester.pumpAndSettle();
    expect(find.text('Bedug'), findsOneWidget);
    expect(find.text('Adzan'), findsOneWidget);
    // Listen to a sample before choosing.
    await tester.tap(find.byTooltip('Dengarkan Bedug'));
    await tester.pump();
    expect(player.played, ['asset:///assets/sounds/adzan_bedug.ogg']);
    await tester.tap(find.text('Bedug'));
    await tester.pumpAndSettle();
    // Closing the sheet stops the sample.
    await tester.tapAt(const Offset(195, 40));
    await tester.pumpAndSettle();
    expect(player.disposed, isTrue);
    expect(find.textContaining('Bedug ·'), findsOneWidget);

    final sahurRow = find
        .ancestor(
          of: find.text('Pengingat sahur'),
          matching: find.byType(InkWell),
        )
        .first;
    await tester.scrollUntilVisible(find.text('Pengingat sahur'), -100);
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: sahurRow, matching: find.byType(Switch)),
    );
    await tester.pumpAndSettle();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(AdzanNotifier.sahurKey), isTrue);
    expect(prefs.getString(AdzanNotifier.soundKey), 'bedug');
  });
}
