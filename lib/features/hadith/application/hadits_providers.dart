import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muslimku/core/network/api_service.dart';
import 'package:muslimku/core/storage/content_cache.dart';
import 'package:muslimku/core/time/clock_provider.dart' show clockProvider;
import 'package:muslimku/core/utils/daily_pick.dart';
import 'package:muslimku/features/hadith/domain/hadith_model.dart';

/// Number of the "Hadits hari ini", see `core/utils/daily_pick.dart`.
export 'package:muslimku/core/utils/daily_pick.dart' show dailyArbainNumber;

/// Hadith texts from MyQuran, saved on the phone (see [ContentCache]) so the
/// lists and every hadith that was opened once also work offline.
class HaditsRepository {
  HaditsRepository(this._api, this._cache);

  final ApiService _api;
  final ContentCache _cache;

  static const arbainKey = 'lists/arbain.json';
  static const perawiKey = 'lists/perawi.json';

  /// `hadits/bm/12.json`, `hadits/bukhari/52.json`.
  static String entryKey(HaditsBook book, int number) =>
      'hadits/${book.slug}/$number.json';

  /// The 42 hadiths of Arbain An-Nawawi (`hadits/arbain/semua`), by number.
  Future<Cached<List<HaditsEntry>>> arbain({bool refresh = false}) async {
    final cached = await _cache.list(
      arbainKey,
      _api.getAllHadithArbain,
      refresh: refresh,
    );
    return cached.map(
      (items) =>
          [for (final item in items) HaditsEntry.arbain(item)]
            ..sort((a, b) => a.number.compareTo(b.number)),
    );
  }

  /// The saved Arbain list only, without a request (null when not saved yet).
  /// Used when planning adzan reminders, which must not wait for the network.
  Future<List<HaditsEntry>?> savedArbain() async {
    final saved = await _cache.peek(arbainKey);
    final data = saved?.data;
    if (data is! List) return null;
    return [
      for (final item in data)
        if (item is Map) HaditsEntry.arbain(Map<String, dynamic>.from(item)),
    ]..sort((a, b) => a.number.compareTo(b.number));
  }

  /// The 9 perawi in display order. Totals come from `hadits/perawi`; without
  /// internet and without a saved copy the built-in totals are used.
  Future<Cached<List<HaditsBook>>> perawi({bool refresh = false}) async {
    try {
      final cached = await _cache.list(
        perawiKey,
        _api.getPerawiList,
        refresh: refresh,
      );
      return cached.map(_withTotals);
    } catch (_) {
      return const Cached(HaditsBook.perawi, offline: true);
    }
  }

  static List<HaditsBook> _withTotals(List<Map<String, dynamic>> items) {
    final totals = {
      for (final item in items)
        '${item['slug']}': int.tryParse('${item['total']}') ?? 0,
    };
    return [
      for (final book in HaditsBook.perawi)
        (totals[book.slug] ?? 0) > 0
            ? book.withTotal(totals[book.slug]!)
            : book,
    ];
  }

  /// One Bulughul Maram or perawi hadith (`hadits/bm/12`, `hadits/bukhari/52`).
  /// Arbain hadiths come from [arbain].
  Future<Cached<HaditsEntry>> entry(HaditsBook book, int number) async {
    if (book.isArbain) {
      final list = await arbain();
      return list.map((items) => _arbainNumber(items, number));
    }
    final cached = await _cache.object(
      entryKey(book, number),
      () => book.isBulughulMaram
          ? _api.getHadithBulughulByNumber(number)
          : _api.getHadithByPerawi(book.slug, number),
    );
    return cached.map(
      (json) => book.isBulughulMaram
          ? HaditsEntry.bulughulMaram(json, number: number)
          : HaditsEntry.perawi(book, json, number: number),
    );
  }
}

HaditsEntry _arbainNumber(List<HaditsEntry> items, int number) {
  for (final item in items) {
    if (item.number == number) return item;
  }
  throw StateError('Arbain No. $number tidak ada');
}

final haditsRepositoryProvider = Provider<HaditsRepository>(
  (ref) => HaditsRepository(
    ref.watch(apiServiceProvider),
    ref.watch(contentCacheProvider),
  ),
);

/// Arbain An-Nawawi, kept for the whole session (list, daily card, detail).
final arbainListProvider = FutureProvider<Cached<List<HaditsEntry>>>(
  (ref) => ref.watch(haditsRepositoryProvider).arbain(),
);

/// The 9 perawi with their totals.
final perawiBooksProvider = FutureProvider<Cached<List<HaditsBook>>>(
  (ref) => ref.watch(haditsRepositoryProvider).perawi(),
);

/// A hadith of a book by number, e.g. `(book: HaditsBook.bulughulMaram, number: 12)`.
typedef HaditsRef = ({HaditsBook book, int number});

/// One hadith for the detail page: Arbain from [arbainListProvider], the
/// others from MyQuran (saved per number).
final haditsEntryProvider = FutureProvider.autoDispose
    .family<Cached<HaditsEntry>, HaditsRef>((ref, id) async {
      if (id.book.isArbain) {
        final list = await ref.watch(arbainListProvider.future);
        return list.map((items) => _arbainNumber(items, id.number));
      }
      return ref.watch(haditsRepositoryProvider).entry(id.book, id.number);
    });

/// Today's date at midnight. It only changes once a day although the clock
/// ticks every few seconds, so "Hadits hari ini" is not rebuilt each tick.
final haditsTodayProvider = Provider.autoDispose<DateTime>((ref) {
  final now = ref.watch(clockProvider).valueOrNull ?? DateTime.now();
  return DateTime(now.year, now.month, now.day);
});

/// "Hadits hari ini": today's Arbain hadith, shared by the Hadits tab and the
/// Beranda card so both show the same one.
final dailyArbainProvider = Provider.autoDispose<AsyncValue<HaditsEntry>>((
  ref,
) {
  final today = ref.watch(haditsTodayProvider);
  return ref.watch(arbainListProvider).whenData((list) {
    final items = list.data;
    final number = dailyArbainNumber(today, count: items.length);
    for (final item in items) {
      if (item.number == number) return item;
    }
    // MyQuran skipped a number: take the hadith at that place instead.
    return items[(number - 1) % items.length];
  });
});
