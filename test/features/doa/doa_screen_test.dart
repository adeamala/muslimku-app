import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:muslimku/features/doa/presentation/doa_detail_screen.dart';
import 'package:muslimku/features/doa/presentation/doa_screen.dart';
import 'package:muslimku/features/doa/presentation/doa_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_husna_doa_api.dart';

const _tab = Scaffold(body: DoaScreen());

/// The chip with [label] (its count is a separate text), also when it is
/// scrolled out of view.
Finder _chip(String label) => find.ancestor(
  of: find.text(label, skipOffstage: false),
  matching: find.byWidgetPredicate(
    (w) => w.runtimeType.toString() == 'SenjaChip',
    skipOffstage: false,
  ),
);

void main() {
  setUpAll(() => initializeDateFormatting('id_ID', null));
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('chips count every category and filter the list', (tester) async {
    await pumpSenja(tester, _tab, api: FakeHusnaDoaApi());
    expect(find.text('11 doa pilihan'), findsOneWidget);
    expect(find.text('Semua doa'), findsOneWidget);
    for (final (label, count) in [
      ('Semua', '11'),
      ('Harian', '5'),
      ("Al-Qur'an", '3'),
      ('Haji', '2'),
      ('Hadits', '1'),
    ]) {
      expect(
        find.descendant(
          of: _chip(label),
          matching: find.text(count, skipOffstage: false),
          skipOffstage: false,
        ),
        findsOneWidget,
        reason: label,
      );
    }

    await tester.ensureVisible(_chip('Haji'));
    await tester.pump();
    await tester.tap(_chip('Haji'));
    await tester.pump();
    expect(find.text('Doa Haji'), findsOneWidget);
    expect(find.text('Doa Masuk kota Mekkah'), findsOneWidget);
    expect(find.text('Doa Masuk Masjidil Haram'), findsOneWidget);
    expect(find.text('Doa Sebelum Makan'), findsNothing);
    expect(find.text('Haji'), findsNWidgets(3), reason: 'chip + two rows');

    await tester.ensureVisible(_chip('Semua'));
    await tester.pump();
    await tester.tap(_chip('Semua'));
    await tester.pump();
    expect(find.text('Doa Mohon Kebaikan Dunia dan Akhirat'), findsOneWidget);
  });

  testWidgets('search matches title and meaning, with an empty state', (
    tester,
  ) async {
    await pumpSenja(tester, _tab, api: FakeHusnaDoaApi());
    await tester.enterText(find.byType(TextField), 'MAKAN');
    await tester.pump();
    expect(find.text('Doa Sebelum Makan'), findsOneWidget);
    expect(find.text('Doa Sesudah Makan'), findsOneWidget);
    expect(find.text('Doa Keluar Rumah'), findsNothing);

    await tester.enterText(find.byType(TextField), 'tawakkal');
    await tester.pump();
    expect(find.text('Doa Keluar Rumah'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pump();
    expect(find.text('Tidak ada doa yang cocok'), findsOneWidget);

    await tester.tap(find.byTooltip('Hapus pencarian'));
    await tester.pump();
    expect(find.text('Doa Sebelum Makan'), findsOneWidget);
  });

  testWidgets('a star saves the doa to Favorit, newest first', (tester) async {
    await pumpSenja(tester, _tab, api: FakeHusnaDoaApi());
    expect(find.text('Favorit'), findsNothing);

    await tester.tap(find.byTooltip('Simpan ke favorit').at(4)); // Bercermin
    await tester.pump();
    await tester.tap(
      find.byTooltip('Simpan ke favorit').at(4),
    ); // Sebelum Makan
    await tester.pump();
    expect(find.text('Favorit'), findsOneWidget);

    final cards = find.byType(DoaFavouriteCard);
    expect(cards, findsNWidgets(2));
    expect(
      tester.widget<DoaFavouriteCard>(cards.first).doa.title,
      'Doa Sebelum Makan',
    );
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('favorites_doa'), [
      'Doa Ketika Bercermin',
      'Doa Sebelum Makan',
    ]);
  });

  testWidgets('a row opens the doa; the bottom bar walks the shown list', (
    tester,
  ) async {
    await pumpSenja(tester, _tab, api: FakeHusnaDoaApi());
    await tester.tap(_chip('Harian'));
    await tester.pump();
    await tester.tap(find.text('Doa Sebelum Makan'));
    await tester.pumpAndSettle();

    expect(find.byType(DoaDetailScreen), findsOneWidget);
    expect(find.text('Doa Harian'), findsOneWidget);
    expect(find.text('5 doa'), findsOneWidget);
    expect(find.text('ARTINYA'), findsOneWidget);
    expect(find.text('Doa Ketika Bercermin'), findsOneWidget);
    expect(find.text('Doa Sesudah Makan'), findsOneWidget);

    await tester.tap(find.text('Berikutnya'));
    await tester.pump();
    expect(find.text('Doa Sesudah Makan'), findsOneWidget);
    expect(find.text('Doa Sebelum Tidur'), findsOneWidget);
    expect(find.text('Doa Ketika Bercermin'), findsNothing);
  });
}
