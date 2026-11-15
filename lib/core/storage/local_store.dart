import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

/// Key-value store for offline content (JSON text). Keys may contain `/`.
///
/// Errors never escape: a store that cannot be reached behaves as empty, so
/// the app falls back to the network instead of failing.
abstract class LocalStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);

  /// Keys that start with [prefix].
  Future<List<String>> keys(String prefix);

  /// Total size in bytes of the values under [prefix].
  Future<int> size(String prefix);

  Future<Object?> readJson(String key) async {
    final text = await read(key);
    if (text == null) return null;
    try {
      return jsonDecode(text);
    } catch (_) {
      return null;
    }
  }

  Future<void> writeJson(String key, Object? value) =>
      write(key, jsonEncode(value));
}

class MemoryLocalStore extends LocalStore {
  final Map<String, String> values = {};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<List<String>> keys(String prefix) async =>
      values.keys.where((k) => k.startsWith(prefix)).toList()..sort();

  @override
  Future<int> size(String prefix) async => values.entries
      .where((e) => e.key.startsWith(prefix))
      .fold<int>(0, (sum, e) => sum + utf8.encode(e.value).length);
}

/// Files under the app support directory (`<support>/offline/<key>`).
class FileLocalStore extends LocalStore {
  FileLocalStore({Future<Directory> Function()? baseDir})
    : _baseDir = baseDir ?? _defaultDir;

  static Future<Directory> _defaultDir() async =>
      Directory('${(await getApplicationSupportDirectory()).path}/offline');

  final Future<Directory> Function() _baseDir;
  Directory? _root;

  Future<Directory?> _dir() async {
    if (_root != null) return _root;
    try {
      return _root = await _baseDir();
    } catch (_) {
      return null; // e.g. no path_provider in tests
    }
  }

  static String _safe(String key) => key
      .split('/')
      .where((p) => p.isNotEmpty && p != '.' && p != '..')
      .map((p) => p.replaceAll(RegExp(r'[^A-Za-z0-9_.-]'), '_'))
      .join('/');

  Future<File?> _file(String key) async {
    final dir = await _dir();
    return dir == null ? null : File('${dir.path}/${_safe(key)}');
  }

  @override
  Future<String?> read(String key) async {
    try {
      final file = await _file(key);
      if (file == null || !await file.exists()) return null;
      return await file.readAsString();
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(String key, String value) async {
    try {
      final file = await _file(key);
      if (file == null) return;
      await file.parent.create(recursive: true);
      final tmp = File('${file.path}.tmp');
      await tmp.writeAsString(value, flush: true);
      await tmp.rename(file.path);
    } catch (_) {}
  }

  @override
  Future<void> delete(String key) async {
    try {
      final file = await _file(key);
      if (file != null && await file.exists()) await file.delete();
    } catch (_) {}
  }

  Future<List<(String, File)>> _entries(String prefix) async {
    final dir = await _dir();
    if (dir == null || !await dir.exists()) return const [];
    final out = <(String, File)>[];
    await for (final e in dir.list(recursive: true, followLinks: false)) {
      if (e is! File || e.path.endsWith('.tmp')) continue;
      final key = e.path.substring(dir.path.length + 1);
      if (key.startsWith(prefix)) out.add((key, e));
    }
    out.sort((a, b) => a.$1.compareTo(b.$1));
    return out;
  }

  @override
  Future<List<String>> keys(String prefix) async {
    try {
      return [for (final e in await _entries(prefix)) e.$1];
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<int> size(String prefix) async {
    try {
      var total = 0;
      for (final e in await _entries(prefix)) {
        total += await e.$2.length();
      }
      return total;
    } catch (_) {
      return 0;
    }
  }
}

/// True under `flutter test`, where real files would leak between tests.
bool get runningInFlutterTest =>
    !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');

/// Files on phones; memory on the web build used for visual checks and in tests.
final localStoreProvider = Provider<LocalStore>(
  (ref) =>
      kIsWeb || runningInFlutterTest ? MemoryLocalStore() : FileLocalStore(),
);
