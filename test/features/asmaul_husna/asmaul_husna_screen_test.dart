import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:muslimku/core/storage/local_store.dart';
import 'package:muslimku/features/asmaul_husna/presentation/asmaul_husna_screen.dart';
import 'package:muslimku/features/asmaul_husna/presentation/husna_name_card.dart';
import 'package:muslimku/features/asmaul_husna/presentation/husna_quiz_screen.dart';
import 'package:muslimku/features/tasbih/presentation/tasbih_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_husna_doa_api.dart';

const _tab = Scaffold(body: AsmaulHusnaScreen());

void main() {
  setUpAll(() => initializeDateFormatting('id_ID', null));
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('shows the name of the day above the grid', (tester) async {
    await pumpSenja(tester, _tab, api: FakeHusnaDoaApi());
    // 25 Oct is day 298; with 13 names that is the 12th.
    expect(find.text('NAMA HARI INI · 12 DARI 13'), findsOneWidget);
    expect(find.text('Al-Bâri’u'), findsWidgets);
    expect(find.text('Dzikir 33×'), findsOneWidget);
    expect(find.text('Bagikan'), findsOneWidget);
    expect(find.text('Ar-Rahmânu'), findsOneWidget);
    expect(find.text('Yang Maha Penyayang'), findsOneWidget);
  });

  testWidgets('Hafalan hides the meanings until a card is tapped', (
    tester,
  ) async {
    await pumpSenja(tester, _tab, api: FakeHusnaDoaApi());
    await tester.tap(find.text('Hafalan'));
    await tester.pump();
    expect(find.text('Yang Maha Penyayang'), findsNothing);
    expect(find.text('Yang Mahasuci'), findsNothing);
    expect(find.text('Ketuk untuk melihat arti'), findsWidgets);

    await tester.tap(find.text('Ar-Raḫîmu'));
    await tester.pump();
    expect(find.text('Yang Maha Penyayang'), findsOneWidget);
    expect(find.text('Yang Mahasuci'), findsNothing);

    await tester.tap(find.text('Semua'));
    await tester.pump();
    expect(find.text('Yang Mahasuci'), findsOneWidget);
    expect(find.text('Ketuk untuk melihat arti'), findsNothing);
  });

  testWidgets('a card opens its sheet, and Dzikir 33× opens the tasbih', (
    tester,
  ) async {
    await pumpSenja(tester, _tab, api: FakeHusnaDoaApi());
    await tester.tap(find.text('Al-Quddûsu'));
    await tester.pumpAndSettle();
    expect(find.text('No. 4'), findsOneWidget);
    expect(find.text('Yang Mahasuci'), findsNWidgets(2));

    await tester.tap(find.text('Dzikir 33×').last);
    await tester.pumpAndSettle();
    final tasbih = tester.widget<TasbihScreen>(find.byType(TasbihScreen));
    expect(tasbih.preset?.latin, 'Al-Quddûsu');
    expect(tasbih.preset?.target, 33);
  });

  testWidgets('Kuis opens the quiz page', (tester) async {
    await pumpSenja(tester, _tab, api: FakeHusnaDoaApi());
    await tester.tap(find.text('Kuis'));
    await tester.pumpAndSettle();
    expect(find.byType(HusnaQuizScreen), findsOneWidget);
    expect(find.text('Kuis Asmaul Husna'), findsOneWidget);
  });

  testWidgets('card content is centred in its card', (tester) async {
    // A wide surface: with real fonts the texts are narrower than the card,
    // and a shrink-wrapped column would sit on the left.
    await pumpSenja(tester, _tab, api: FakeHusnaDoaApi());
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    await settleSenja(tester);
    final card = find.ancestor(
      of: find.text('Ar-Raḫîmu'),
      matching: find.byType(HusnaNameCard),
    );
    expect(
      tester.getCenter(find.text('Ar-Raḫîmu')).dx,
      moreOrLessEquals(tester.getCenter(card).dx, epsilon: 1),
    );
  });

  testWidgets('offline with a saved copy shows the banner and the names', (
    tester,
  ) async {
    final store = MemoryLocalStore();
    // A copy saved 40 days ago is refreshed first; offline it is used as is.
    await store.writeJson('lists/husna.json', {
      'savedAt': DateTime.now()
          .subtract(const Duration(days: 40))
          .toIso8601String(),
      'data': FakeHusnaDoaApi.husna,
    });
    await pumpSenja(
      tester,
      _tab,
      api: FakeHusnaDoaApi(offline: true),
      store: store,
    );
    expect(find.text('Sedang offline'), findsOneWidget);
    expect(find.text('Ar-Rahmânu'), findsOneWidget);
  });

  testWidgets('offline without a saved copy offers to try again', (
    tester,
  ) async {
    final api = FakeHusnaDoaApi(offline: true);
    await pumpSenja(tester, _tab, api: api);
    expect(find.text('Coba lagi'), findsOneWidget);

    api.offline = false;
    await tester.tap(find.text('Coba lagi'));
    await settleSenja(tester);
    expect(find.text('Ar-Rahmânu'), findsOneWidget);
  });
}
