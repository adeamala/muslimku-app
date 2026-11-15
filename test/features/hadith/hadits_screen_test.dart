import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:muslimku/core/storage/local_store.dart';
import 'package:muslimku/features/hadith/presentation/hadith_screen.dart';
import 'package:muslimku/features/hadith/presentation/hadits_detail_screen.dart';
import 'package:muslimku/shared/application/favorites_provider.dart';
import 'package:muslimku/shared/widgets/senja/senja.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_hadits_api.dart';
import 'pump_hadits.dart';

Finder _segment(String label) => find.descendant(
  of: find.byType(SenjaSegmented),
  matching: find.textContaining(label),
);

void main() {
  setUpAll(() => initializeDateFormatting('id_ID', null));
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Arbain shows today\'s hadith and the list with citations', (
    tester,
  ) async {
    await pumpHadits(tester);
    // 25 Oct is day 298 of the year: (298 - 1) % 42 + 1 = No. 4.
    expect(find.text('HADITS HARI INI · NO. 4'), findsOneWidget);
    expect(find.text('Takdir Setiap Manusia sudah Tertulis'), findsWidgets);
    expect(find.text('Amalan Bergantung pada Niat'), findsOneWidget);
    expect(find.text('HR. Bukhari & Muslim'), findsWidgets);
    expect(find.text('HR. Muslim'), findsWidgets);
    expect(find.text('Cari judul atau nomor hadits'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('"Hadits hari ini" has the 19 px title of the design', (
    tester,
  ) async {
    await pumpHadits(tester);
    final title = tester.widget<Text>(
      find.descendant(
        of: find.byType(SenjaFeatureCard),
        matching: find.text('Takdir Setiap Manusia sudah Tertulis'),
      ),
    );
    expect(title.style?.fontSize, 19);
  });

  testWidgets('search finds hadiths by number or title', (tester) async {
    await pumpHadits(tester);
    final search = find.byType(TextField);

    await tester.enterText(search, '16');
    await tester.pump();
    expect(find.text('Janganlah Engkau Marah'), findsOneWidget);
    expect(find.text('Amalan Bergantung pada Niat'), findsNothing);

    await tester.enterText(search, 'RUKUN');
    await tester.pump();
    expect(find.text('Rukun Islam, Iman, dan Ihsan'), findsOneWidget);
    expect(find.text('Janganlah Engkau Marah'), findsNothing);

    await tester.enterText(search, 'tidak ada');
    await tester.pump();
    expect(
      find.text('Tidak ada hadits Arbain untuk "tidak ada".'),
      findsOneWidget,
    );
  });

  testWidgets('a bookmark shows the "Ditandai" filter', (tester) async {
    await pumpHadits(tester);
    expect(find.text('Ditandai'), findsNothing);

    await tester.tap(find.byTooltip('Tandai hadits').first);
    await tester.pump();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(HadithScreen)),
    );
    expect(container.read(favoritesProvider('hadits')), {'arbain:1'});

    await tester.tap(find.text('Ditandai'));
    await tester.pump();
    expect(find.text('Amalan Bergantung pada Niat'), findsOneWidget);
    expect(find.text('Rukun Islam, Iman, dan Ihsan'), findsNothing);
  });

  testWidgets('"Ditandai" also lists marked Bulughul Maram hadiths', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'favorites_hadits': ['bm:12', 'arbain:16'],
    });
    await pumpHadits(tester);
    await tester.tap(find.text('Ditandai'));
    await tester.pump();
    expect(find.text('Janganlah Engkau Marah'), findsOneWidget);
    expect(find.text('Amalan Bergantung pada Niat'), findsNothing);
    expect(find.text('Hadits No. 12'), findsOneWidget);
    expect(find.text('Bulughul Maram'), findsWidgets);

    await tester.tap(find.text('Hadits No. 12'));
    await settleHadits(tester);
    expect(find.text('Bulughul Maram · No. 12'), findsOneWidget);
  });

  testWidgets('segments switch to Bulughul Maram and 9 Perawi', (tester) async {
    final api = await pumpHadits(tester);
    expect(api.count('hadits/bm/1'), 0, reason: 'loads only when opened');

    await tester.tap(_segment('Bulughul Maram'));
    await settleHadits(tester);
    expect(find.text('Lompat ke hadits'), findsOneWidget);
    expect(find.text('Nomor 1–1.597'), findsOneWidget);
    expect(find.text('”Isi Bulughul Maram nomor 1.”'), findsOneWidget);
    expect(api.count('hadits/bm/1'), 1);
    expect(api.maxInFlight, lessThanOrEqualTo(4));

    await tester.tap(_segment('9 Perawi'));
    await settleHadits(tester);
    expect(find.text('Pilih perawi'), findsOneWidget);
    expect(find.text('38.102 hadits'), findsOneWidget);
    expect(find.text('Nomor 1–6.638'), findsOneWidget);
    expect(find.text('البخاري'), findsOneWidget);
    expect(find.text('Darimi'), findsOneWidget);

    await tester.tap(_segment('Arbain'));
    await tester.pump();
    expect(find.text('HADITS HARI INI · NO. 4'), findsOneWidget);
  });

  testWidgets('jump card checks the range and opens the hadith', (
    tester,
  ) async {
    final api = await pumpHadits(tester);
    await tester.tap(_segment('Bulughul Maram'));
    await settleHadits(tester);

    await tester.enterText(find.byType(TextField), '2000');
    await tester.tap(find.text('Buka'));
    await tester.pump();
    expect(find.text('Nomor 2000 tidak ada. Pilih 1–1.597.'), findsOneWidget);
    expect(find.byType(HaditsDetailScreen), findsNothing);

    await tester.enterText(find.byType(TextField), '12');
    await tester.tap(find.text('Buka'));
    await settleHadits(tester);
    expect(find.byType(HaditsDetailScreen), findsOneWidget);
    expect(find.text('Bulughul Maram · No. 12'), findsOneWidget);
    expect(find.text('dari 1.597 hadits'), findsOneWidget);
    expect(api.count('hadits/bm/12'), 1);
  });

  testWidgets('a perawi tile opens the last number read', (tester) async {
    SharedPreferences.setMockInitialValues({'hadits_last_muslim': 52});
    final api = await pumpHadits(tester);
    await tester.tap(_segment('9 Perawi'));
    await settleHadits(tester);

    await tester.tap(find.text('Muslim'));
    await settleHadits(tester);
    expect(find.text('Muslim · No. 52'), findsOneWidget);
    expect(find.text('dari 4.930 hadits'), findsOneWidget);
    expect(find.text('HR. Muslim'), findsOneWidget);
    expect(api.count('hadits/muslim/52'), 1);

    await tester.tap(find.text('No. 53'));
    await settleHadits(tester);
    expect(find.text('Muslim · No. 53'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('hadits_last_muslim'), 53);

    await tester.tap(find.byTooltip('Kembali'));
    await settleHadits(tester);
    // The tile is now the selected perawi of the jump card.
    expect(find.text('Nomor 1–4.930'), findsOneWidget);
  });

  testWidgets('offline with a saved list shows the banner', (tester) async {
    final store = MemoryLocalStore();
    await pumpHadits(tester, store: store);
    await tester.pumpWidget(const SizedBox());

    final offline = FakeHaditsApi(offline: true);
    await pumpHadits(tester, api: offline, store: store);
    expect(find.text('Amalan Bergantung pada Niat'), findsOneWidget);
    expect(
      find.text('Sedang offline'),
      findsNothing,
      reason: 'saved copy is fresh',
    );

    await tester.fling(
      find.text('Amalan Bergantung pada Niat'),
      const Offset(0, 400),
      1000,
    );
    await settleHadits(tester);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Sedang offline'), findsOneWidget);
    expect(find.text('Amalan Bergantung pada Niat'), findsOneWidget);
  });

  testWidgets('no overflow at 130 % text size', (tester) async {
    await pumpHadits(tester, textScale: 1.3);
    expect(tester.takeException(), isNull);
    await tester.tap(_segment('Bulughul Maram'));
    await settleHadits(tester);
    expect(tester.takeException(), isNull);
    await tester.tap(_segment('9 Perawi'));
    await settleHadits(tester);
    expect(tester.takeException(), isNull);
  });
}
