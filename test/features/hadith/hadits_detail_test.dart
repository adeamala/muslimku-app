import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:muslimku/core/storage/local_store.dart';
import 'package:muslimku/features/hadith/domain/hadith_model.dart';
import 'package:muslimku/features/hadith/presentation/hadits_detail_screen.dart';
import 'package:muslimku/features/reading/application/reading_settings_provider.dart';
import 'package:muslimku/shared/application/favorites_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_hadits_api.dart';
import 'pump_hadits.dart';

Widget _detail(HaditsBook book, int number) =>
    HaditsDetailScreen(book: book, number: number);

void main() {
  setUpAll(() => initializeDateFormatting('id_ID', null));
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Arbain detail steps to the neighbours from the list', (
    tester,
  ) async {
    final api = await pumpHadits(tester, home: _detail(HaditsBook.arbain, 16));
    expect(find.text('Arbain · No. 16'), findsOneWidget);
    expect(find.text('dari 42 hadits'), findsOneWidget);
    expect(find.text('Arbain An-Nawawi'), findsOneWidget);
    expect(find.text('Janganlah Engkau Marah'), findsOneWidget);
    expect(find.text('HR. Bukhari'), findsOneWidget);
    expect(find.text('TERJEMAHAN'), findsOneWidget);
    expect(find.textContaining('Berilah aku nasihat'), findsOneWidget);
    expect(find.text('No. 15'), findsOneWidget);

    await tester.tap(find.text('No. 17'));
    await tester.pump();
    expect(find.text('Arbain · No. 17'), findsOneWidget);
    expect(find.text('Berbuat Baik dalam Segala Hal'), findsOneWidget);
    expect(find.text('No. 18'), findsOneWidget);

    await tester.tap(find.text('No. 16'));
    await tester.pump();
    expect(find.text('Janganlah Engkau Marah'), findsOneWidget);
    expect(api.count('hadits/arbain/semua'), 1);
  });

  testWidgets('the first and last hadith cannot step further', (tester) async {
    await pumpHadits(tester, home: _detail(HaditsBook.arbain, 42));
    expect(find.text('Akhir'), findsOneWidget);
    await tester.tap(find.text('Akhir'));
    await tester.pump();
    expect(find.text('Arbain · No. 42'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await pumpHadits(tester, home: _detail(HaditsBook.arbain, 1));
    expect(find.text('Awal'), findsOneWidget);
    expect(find.text('No. 2'), findsOneWidget);
  });

  testWidgets('Bulughul Maram detail fetches the next number', (tester) async {
    final api = await pumpHadits(
      tester,
      home: _detail(HaditsBook.bulughulMaram, 12),
    );
    expect(find.text('Bulughul Maram · No. 12'), findsOneWidget);
    expect(find.text('Hadits No. 12'), findsOneWidget);
    expect(
      find.text(
        'Dari Abu Hurairah bahwa Rasulullah bersabda: '
        '"Isi Bulughul Maram nomor 12."',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Hadis No.'), findsNothing);

    await tester.tap(find.text('No. 13'));
    await settleHadits(tester);
    expect(find.text('Bulughul Maram · No. 13'), findsOneWidget);
    expect(find.text('Hadits No. 13'), findsOneWidget);
    expect(api.requests, ['hadits/bm/12', 'hadits/bm/13']);

    await tester.tap(find.text('No. 12'));
    await settleHadits(tester);
    expect(find.text('Hadits No. 12'), findsOneWidget);
    expect(api.count('hadits/bm/12'), 1, reason: 'saved copy is reused');
  });

  testWidgets('a hadith that cannot load offers "Coba lagi"', (tester) async {
    final api = FakeHaditsApi(offline: true);
    await pumpHadits(
      tester,
      api: api,
      home: _detail(HaditsBook.perawi.first, 7),
    );
    expect(find.text('Hadits belum bisa dibuka'), findsOneWidget);

    api.offline = false;
    await tester.tap(find.text('Coba lagi'));
    await settleHadits(tester);
    expect(find.text('Bukhari · No. 7'), findsOneWidget);
    expect(find.text('HR. Bukhari'), findsOneWidget);
    expect(find.textContaining('hadits nomor 7'), findsOneWidget);
  });

  testWidgets('a visited hadith opens again offline', (tester) async {
    final store = MemoryLocalStore();
    await pumpHadits(
      tester,
      store: store,
      home: _detail(HaditsBook.bulughulMaram, 5),
    );
    await tester.pumpWidget(const SizedBox());

    await pumpHadits(
      tester,
      api: FakeHaditsApi(offline: true),
      store: store,
      home: _detail(HaditsBook.bulughulMaram, 5),
    );
    expect(find.text('Hadits No. 5'), findsOneWidget);
  });

  testWidgets('bookmark, copy and the Arabic size sheet', (tester) async {
    final copied = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied.add((call.arguments as Map)['text'] as String);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await pumpHadits(tester, home: _detail(HaditsBook.arbain, 16));
    final container = ProviderScope.containerOf(
      tester.element(find.byType(HaditsDetailScreen)),
    );

    await tester.tap(find.byTooltip('Tandai hadits'));
    await tester.pump();
    expect(container.read(favoritesProvider('hadits')), {'arbain:16'});
    expect(find.byTooltip('Hapus tanda'), findsOneWidget);

    await tester.tap(find.byTooltip('Salin hadits'));
    await tester.pump();
    expect(find.text('Hadits disalin'), findsOneWidget);
    expect(copied.single, startsWith('Janganlah Engkau Marah\n\n'));
    expect(copied.single, contains('(Arbain An-Nawawi No. 16, HR. Bukhari)'));

    await tester.tap(find.byTooltip('Ukuran huruf Arab'));
    await settleHadits(tester);
    expect(find.text('Ukuran huruf Arab'), findsWidgets);
    expect(find.text('28'), findsOneWidget);
    await tester.tap(find.byType(Slider));
    await tester.pump();
    expect(container.read(readingSettingsProvider).arabicSize, 30);
  });

  testWidgets('no overflow at 130 % text size', (tester) async {
    await pumpHadits(
      tester,
      textScale: 1.3,
      home: _detail(HaditsBook.bulughulMaram, 1597),
    );
    expect(find.text('Akhir'), findsOneWidget);
    expect(tester.takeException(), isNull);
    // The long title shrinks instead of losing its number to "…".
    final barScale = MediaQuery.textScalerOf(
      tester.element(find.text('Bulughul Maram · No. 1597')),
    ).scale(10);
    expect(barScale, lessThan(13));
    expect(barScale, greaterThanOrEqualTo(8));
    await tester.pumpWidget(const SizedBox());
    await pumpHadits(
      tester,
      textScale: 1.3,
      home: _detail(HaditsBook.arbain, 16),
    );
    expect(tester.takeException(), isNull);
  });
}
