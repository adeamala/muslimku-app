import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:muslimku/core/storage/local_store.dart';

/// A value and where it came from.
class Cached<T> {
  const Cached(
    this.data, {
    this.fromCache = false,
    this.offline = false,
    this.savedAt,
  });

  final T data;

  /// Served from the phone instead of a fresh download.
  final bool fromCache;

  /// The download failed and the saved copy was used instead.
  final bool offline;

  /// When the saved copy was written (null for fresh data that could not be saved).
  final DateTime? savedAt;

  Cached<R> map<R>(R Function(T data) convert) => Cached(
    convert(data),
    fromCache: fromCache,
    offline: offline,
    savedAt: savedAt,
  );
}

/// `true` while the last MyQuran request failed and saved data was shown.
/// Drives the "Sedang offline" banner; any successful request clears it.
final networkStatusProvider = NotifierProvider<NetworkStatus, bool>(
  NetworkStatus.new,
);

class NetworkStatus extends Notifier<bool> {
  @override
  bool build() {
    return false;
  }

  void markOffline() {
    if (!state) state = true;
  }

  void markOnline() {
    if (state) state = false;
  }
}

/// Network-first content with a saved copy on the phone.
///
/// Within [maxAge] the saved copy is used without a request. Older copies are
/// refreshed; when the refresh fails the saved copy is returned with
/// `offline: true`. Without any copy the error is rethrown.
class ContentCache {
  ContentCache(
    this.store, {
    void Function()? onOffline,
    void Function()? onOnline,
    DateTime Function()? clock,
  }) : _onOffline = onOffline,
       _onOnline = onOnline,
       _clock = clock ?? DateTime.now;

  final LocalStore store;
  final void Function()? _onOffline;
  final void Function()? _onOnline;
  final DateTime Function() _clock;

  static const defaultMaxAge = Duration(days: 30);

  Future<Cached<List<Map<String, dynamic>>>> list(
    String key,
    Future<List<Map<String, dynamic>>?> Function() fetch, {
    Duration maxAge = defaultMaxAge,
    bool refresh = false,
  }) async {
    final result = await _get(
      key,
      () async {
        final data = await fetch();
        return data == null || data.isEmpty ? null : data;
      },
      maxAge: maxAge,
      refresh: refresh,
    );
    return result.map(
      (data) => [
        for (final item in data as List) Map<String, dynamic>.from(item as Map),
      ],
    );
  }

  Future<Cached<Map<String, dynamic>>> object(
    String key,
    Future<Map<String, dynamic>?> Function() fetch, {
    Duration maxAge = defaultMaxAge,
    bool refresh = false,
  }) async {
    final result = await _get(key, fetch, maxAge: maxAge, refresh: refresh);
    return result.map((data) => Map<String, dynamic>.from(data as Map));
  }

  /// The saved copy only, without any request.
  Future<Cached<Object>?> peek(String key) async {
    final saved = await _read(key);
    if (saved == null) return null;
    return Cached(saved.$2, fromCache: true, savedAt: saved.$1);
  }

  Future<Cached<Object>> _get(
    String key,
    Future<Object?> Function() fetch, {
    required Duration maxAge,
    required bool refresh,
  }) async {
    final saved = await _read(key);
    if (!refresh && saved != null && _clock().difference(saved.$1) < maxAge) {
      return Cached(saved.$2, fromCache: true, savedAt: saved.$1);
    }
    try {
      final fresh = await fetch();
      if (fresh == null) throw StateError('MyQuran sent no data for $key');
      final now = _clock();
      await store.writeJson(key, {
        'savedAt': now.toIso8601String(),
        'data': fresh,
      });
      _onOnline?.call();
      return Cached(fresh, savedAt: now);
    } catch (_) {
      if (saved == null) rethrow;
      _onOffline?.call();
      return Cached(
        saved.$2,
        fromCache: true,
        offline: true,
        savedAt: saved.$1,
      );
    }
  }

  Future<(DateTime, Object)?> _read(String key) async {
    final json = await store.readJson(key);
    if (json is! Map || json['data'] == null) return null;
    final savedAt = DateTime.tryParse('${json['savedAt']}');
    if (savedAt == null) return null;
    return (savedAt, json['data'] as Object);
  }
}

final contentCacheProvider = Provider<ContentCache>((ref) {
  final status = ref.read(networkStatusProvider.notifier);
  return ContentCache(
    ref.watch(localStoreProvider),
    onOffline: status.markOffline,
    onOnline: status.markOnline,
  );
});
