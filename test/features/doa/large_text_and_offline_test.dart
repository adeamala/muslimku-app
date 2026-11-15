import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:muslimku/features/asmaul_husna/application/husna_quiz_provider.dart';
import 'package:muslimku/features/asmaul_husna/presentation/asmaul_husna_screen.dart';
import 'package:muslimku/features/asmaul_husna/presentation/husna_quiz_screen.dart';
import 'package:muslimku/features/doa/application/doa_provider.dart';
import 'package:muslimku/features/doa/presentation/doa_detail_screen.dart';
import 'package:muslimku/features/doa/presentation/doa_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_husna_doa_api.dart';

/// Phone text at 130% (the app's maximum) must not overflow anywhere.
void main() {
  setUpAll(() => initializeDateFormatting('id_ID', null));
  setUp(
    () => SharedPreferences.setMockInitialValues({
      'favorites_doa': ['Doa Sebelum Makan', 'Doa Sebelum Tidur'],
    }),
  );

  final doas = [for (final d in FakeHusnaDoaApi.doa) Doa.fromJson(d)];
  final screens = <String, Widget>{
    'Asmaul Husna tab': const Scaffold(body: AsmaulHusnaScreen()),
    'quiz': const HusnaQuizScreen(),
    'Doa tab': const Scaffold(body: DoaScreen()),
    'doa page': DoaDetailScreen(doas: doas, index: 2),
  };

  for (final MapEntry(key: name, value: screen) in screens.entries) {
    testWidgets('$name fits at 130% text', (tester) async {
      await pumpSenja(
        tester,
        screen,
        api: FakeHusnaDoaApi(),
        textScale: 1.3,
        overrides: [husnaQuizRandomProvider.overrideWithValue(Random(1))],
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Doa tab offline: banner with saved data, or Coba lagi', (
    tester,
  ) async {
    final api = FakeHusnaDoaApi(offline: true);
    await pumpSenja(tester, const Scaffold(body: DoaScreen()), api: api);
    expect(find.text('Doa belum tersimpan'), findsOneWidget);

    api.offline = false;
    await tester.tap(find.text('Coba lagi'));
    await settleSenja(tester);
    expect(find.text('11 doa pilihan'), findsOneWidget);
    expect(find.text('Sedang offline'), findsNothing);

    api.offline = true;
    await tester.fling(find.text('Semua doa'), const Offset(0, 400), 1000);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await settleSenja(tester);
    expect(find.text('Sedang offline'), findsOneWidget);
    expect(find.text('Doa Sebelum Makan'), findsWidgets);
  });
}
