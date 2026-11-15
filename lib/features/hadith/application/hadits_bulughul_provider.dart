import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muslimku/core/state/mounted_flag.dart';
import 'package:muslimku/features/hadith/application/hadits_providers.dart';
import 'package:muslimku/features/hadith/domain/hadith_model.dart';

/// The Bulughul Maram list, loaded page by page while scrolling.
class BulughulListState {
  const BulughulListState({
    this.items = const [],
    this.loading = false,
    this.error,
    this.offline = false,
  });

  final List<HaditsEntry> items;
  final bool loading;

  /// Set when a number could not be loaded; [BulughulListNotifier.loadMore]
  /// tries again from that number.
  final String? error;

  /// Some hadiths came from the phone after a failed request.
  final bool offline;

  int get nextNumber => items.isEmpty ? 1 : items.last.number + 1;
  bool get hasMore => nextNumber <= HaditsBook.bulughulMaram.total;
}

final bulughulListProvider =
    NotifierProvider<BulughulListNotifier, BulughulListState>(
      BulughulListNotifier.new,
    );

class BulughulListNotifier extends Notifier<BulughulListState> {
  late HaditsRepository _repository;
  late MountedFlag _alive;

  @override
  BulughulListState build() {
    _repository = ref.watch(haditsRepositoryProvider);
    _alive = MountedFlag(ref);
    return const BulughulListState();
  }

  static const pageSize = 10;

  /// Requests that may run at the same time (MyQuran has no list endpoint).
  static const parallel = 4;

  /// Loads the next [pageSize] hadiths. A number that fails ends the page
  /// there, so the list never has gaps; calling again retries it.
  Future<void> loadMore() async {
    if (state.loading || !state.hasMore) return;
    final alive = _alive;
    final start = state.nextNumber;
    final end = math.min(start + pageSize - 1, HaditsBook.bulughulMaram.total);
    state = BulughulListState(
      items: state.items,
      loading: true,
      offline: state.offline,
    );

    final numbers = [for (var n = start; n <= end; n++) n];
    final results = List<HaditsEntry?>.filled(numbers.length, null);
    var offline = state.offline;
    var failed = false;
    var next = 0;
    Future<void> worker() async {
      while (!failed && next < numbers.length) {
        final i = next++;
        try {
          final cached = await _repository.entry(
            HaditsBook.bulughulMaram,
            numbers[i],
          );
          results[i] = cached.data;
          offline = offline || cached.offline;
        } catch (_) {
          failed = true;
        }
      }
    }

    await Future.wait([
      for (var w = 0; w < math.min(parallel, numbers.length); w++) worker(),
    ]);
    if (!alive.mounted) return;

    final loaded = results
        .takeWhile((entry) => entry != null)
        .cast<HaditsEntry>();
    state = BulughulListState(
      items: [...state.items, ...loaded],
      error: loaded.length < numbers.length
          ? 'Sebagian hadits belum termuat.'
          : null,
      offline: offline,
    );
  }
}
