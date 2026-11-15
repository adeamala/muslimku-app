import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muslimku/core/storage/content_cache.dart';
import 'package:muslimku/core/storage/local_store.dart';
import 'package:muslimku/features/quran/data/tajweed_repository.dart';
import 'package:muslimku/features/quran/domain/tajweed.dart';
import 'package:muslimku/features/quran/presentation/reader/reader_controls.dart';
import 'package:muslimku/features/quran/presentation/reader/tajweed_style.dart';
import 'package:muslimku/features/reading/application/reading_settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/fake_quran_api.dart';
import 'reader_harness.dart';

void main() {
  test('parses alquran.cloud markup, nested rules included', () {
    final spans = parseTajweed('ذ[n[َٲ]لِكَ [h:11[ٱ]لْكِتَ[n[ـٰ]بُ');
    expect(spans.map((s) => s.text).join(), 'ذَٲلِكَ ٱلْكِتَـٰبُ');
    expect(spans.map((s) => s.rule?.code).toList(), [
      null,
      'n',
      null,
      'h',
      null,
      'n',
      null,
    ]);
    expect(spans[1].rule, TajweedRule.maddaNormal);
    expect(spans[3].rule, TajweedRule.hamzatWasl);

    final nested = parseTajweed('تَعْتَد[o[ُوٓ[s[اْ]\u200cۚ] إِ[g[نّ]َ');
    expect(nested.map((s) => s.text).join(), 'تَعْتَدُوٓاْ\u200cۚ إِنَّ');
    final codes = nested.map((s) => s.rule?.code).toList();
    expect(codes, [null, 'o', 's', 'o', null, 'g', null]);

    // Unknown codes and stray brackets degrade to plain text.
    expect(plainTajweed('[zz[ab] c]'), 'ab c]');
    expect(parseTajweed('abc').single.rule, isNull);
  });

  test('every rule has an Indonesian label and a distinct colour', () {
    expect(TajweedRule.values.length, 17);
    expect(TajweedRule.byCode('q'), TajweedRule.qalqalah);
    expect(TajweedRule.qalqalah.label, 'Qalqalah');
    expect(TajweedRule.ghunnah.label, 'Ghunnah');
    expect(TajweedRule.ikhfa.label, 'Ikhfa');
    expect(TajweedRule.byCode('x'), isNull);
    final colours = {for (final r in TajweedRule.values) r.color};
    expect(colours.length, greaterThanOrEqualTo(12));
  });

  test('the markup of a surah is fetched once and saved', () async {
    final api = FakeQuranApi();
    final store = MemoryLocalStore();
    final repo = TajweedRepository(api: api, cache: ContentCache(store));
    final markup = await repo.surah(2);
    expect(markup.data[2], contains('[n['));
    expect(markup.data[1], contains('[q['));
    expect(markup.data.length, FakeQuranApi.baqarahVerses);
    api.offline = true;
    expect((await repo.surah(2)).fromCache, isTrue);
    expect(
      api.requests.where((r) => r.contains('alquran.cloud')),
      hasLength(1),
    );
    expect(store.values.keys, contains(TajweedRepository.key(2)));
  });

  testWidgets('Tajwid berwarna colours the Arabic and shows the legend', (
    tester,
  ) async {
    final h = await pumpReader(tester, surah: 2, initialAyah: 1);
    // Plain text first: one span, the palette colour.
    // The Arabic is the right-to-left paragraph of the item.
    RichText arabic() => tester
        .widgetList<RichText>(
          find.descendant(
            of: find.byKey(const ValueKey('ayah-2')),
            matching: find.byType(RichText),
          ),
        )
        .firstWhere((r) => r.textDirection == TextDirection.rtl);
    expect(arabic().text.toPlainText(), 'آية 2');
    expect(h.api.requests.where((r) => r.contains('alquran.cloud')), isEmpty);

    await tester.tap(find.byTooltip('Tampilan bacaan'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.widgetWithText(ReaderToggleRow, 'Tajwid berwarna'),
        matching: find.byType(ReaderSwitch),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Legenda tajwid'), findsOneWidget);
    expect(find.text('Qalqalah'), findsOneWidget);
    expect(find.text('Ghunnah'), findsOneWidget);
    await tester.tapAt(const Offset(195, 30));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(ReadingSettingsNotifier.tajwidKey), isTrue);
    // The ayah now shows the alquran.cloud text with coloured spans.
    final span = arabic().text as TextSpan;
    expect(span.toPlainText(), 'ذَٲلِكَ ٱلْكِتَـٰبُ');
    final coloured = <Color>{};
    span.visitChildren((s) {
      final c = s.style?.color;
      if (c != null) coloured.add(c);
      return true;
    });
    expect(coloured, contains(TajweedRule.maddaNormal.color));
    expect(coloured, contains(TajweedRule.hamzatWasl.color));
    expect(
      h.api.requests.where((r) => r.contains('alquran.cloud')),
      hasLength(1),
    );
    expect(
      find.text('Tajwid: teks Uthmani dari alquran.cloud'),
      findsOneWidget,
    );
  });

  testWidgets('without the markup saved, offline, the plain text stays', (
    tester,
  ) async {
    final api = FakeQuranApi(offline: false);
    await pumpReader(
      tester,
      surah: 2,
      api: api,
      prefs: {ReadingSettingsNotifier.tajwidKey: true},
      overrides: const [],
    );
    api.offline = true;
    // The surah itself loaded online; the tajweed request fails: no crash.
    expect(find.byKey(const ValueKey('ayah-1')), findsOneWidget);
  });
}
