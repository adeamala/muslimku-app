import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muslimku/features/doa/application/doa_provider.dart';
import 'package:muslimku/features/doa/presentation/doa_detail_screen.dart';
import 'package:muslimku/features/reading/application/reading_settings_provider.dart';
import 'package:muslimku/shared/widgets/senja/senja.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_husna_doa_api.dart';

class _FakeWake extends ScreenWake {
  final calls = <String>[];

  @override
  Future<void> enable() async => calls.add('on');

  @override
  Future<void> disable() async => calls.add('off');
}

final _all = [for (final d in FakeHusnaDoaApi.doa) Doa.fromJson(d)];
final _haji = filterDoa(_all, category: 'haji');

Future<_FakeWake> _open(WidgetTester tester, List<Doa> list, int index) async {
  final wake = _FakeWake();
  await pumpSenja(
    tester,
    Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => DoaDetailScreen(doas: list, index: index),
              ),
            ),
            child: const Text('buka'),
          ),
        ),
      ),
    ),
    api: FakeHusnaDoaApi(),
    overrides: [screenWakeProvider.overrideWithValue(wake)],
  );
  await tester.tap(find.text('buka'));
  await tester.pumpAndSettle();
  return wake;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'first doa of a category has no Sebelumnya; last has no Berikutnya',
    (tester) async {
      await _open(tester, _haji, 0);
      expect(find.text('Doa Haji'), findsOneWidget);
      expect(find.text('Sebelumnya'), findsNothing);
      expect(find.text('Berikutnya'), findsOneWidget);

      await tester.tap(find.text('Berikutnya'));
      await tester.pump();
      expect(find.text('Doa Masuk Masjidil Haram'), findsOneWidget);
      expect(find.text('Berikutnya'), findsNothing);
      await tester.tap(find.text('Sebelumnya'));
      await tester.pump();
      expect(find.text('Doa Masuk kota Mekkah'), findsOneWidget);
    },
  );

  testWidgets('A− / A+ change the Arabic size by 2 within the limits', (
    tester,
  ) async {
    await _open(tester, _all, 5);
    double arabicSize() =>
        tester.widget<ArabicCard>(find.byType(ArabicCard)).size;
    expect(arabicSize(), 31); // reading size 28 + 3

    await tester.ensureVisible(find.byTooltip('Perbesar huruf Arab'));
    await tester.pump();
    await tester.tap(find.byTooltip('Perbesar huruf Arab'));
    await tester.pump();
    expect(arabicSize(), 33);
    await tester.ensureVisible(find.byTooltip('Perkecil huruf Arab'));
    await tester.pump();
    await tester.tap(find.byTooltip('Perkecil huruf Arab'));
    await tester.tap(find.byTooltip('Perkecil huruf Arab'));
    await tester.pump();
    expect(arabicSize(), 29);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(DoaDetailScreen)),
    );
    expect(container.read(readingSettingsProvider).arabicSize, 26);
  });

  testWidgets(
    'Layar tetap menyala keeps the screen on while the page is open',
    (tester) async {
      final wake = await _open(tester, _all, 5);
      expect(wake.calls, isEmpty, reason: 'off by default');

      await tester.ensureVisible(find.text('Layar tetap menyala'));
      await tester.pump();
      await tester.tap(find.text('Layar tetap menyala'));
      await tester.pump();
      expect(wake.calls, ['on']);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('doa_keep_awake'), isTrue);

      await tester.tap(find.byTooltip('Kembali'));
      await tester.pumpAndSettle();
      expect(find.byType(DoaDetailScreen), findsNothing);
      expect(wake.calls.last, 'off', reason: 'always released when leaving');
    },
  );

  testWidgets('the saved choice switches the screen on when a doa opens', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'doa_keep_awake': true});
    final wake = await _open(tester, _all, 5);
    expect(wake.calls.last, 'on');
    final toggle = tester.widget<SenjaSwitch>(find.byType(SenjaSwitch));
    expect(toggle.value, isTrue);
  });

  testWidgets('the star in the app bar toggles the favourite', (tester) async {
    await _open(tester, _all, 5);
    await tester.tap(find.byTooltip('Simpan ke favorit'));
    await tester.pump();
    expect(find.byTooltip('Hapus dari favorit'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('favorites_doa'), ['Doa Sebelum Makan']);
  });
}
