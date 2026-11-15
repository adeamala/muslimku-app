import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muslimku/features/quran/domain/reciters.dart';
import 'package:path_provider/path_provider.dart';

/// Murottal files saved on the phone, one mp3 per ayah and reciter
/// (`murottal/<cdnId>/<ayahId>.mp3`). The player prefers a saved file.
abstract class MurottalStore {
  static String relativePath(Reciter reciter, int ayahId) =>
      '${reciter.cdnId}/$ayahId.mp3';

  Future<bool> has(Reciter reciter, int ayahId);

  /// `file://` URL of the saved ayah, or null when it is not on the phone.
  Future<String?> url(Reciter reciter, int ayahId);
  Future<void> write(Reciter reciter, int ayahId, List<int> bytes);
  Future<void> delete(Reciter reciter, Iterable<int> ayahIds);
  Future<void> deleteAll();

  /// Saved ayat (all reciters) and their total size.
  Future<int> count();
  Future<int> bytes();

  /// Size of the saved ayat among [ayahIds] for [reciter].
  Future<int> bytesOf(Reciter reciter, Iterable<int> ayahIds);
}

/// Files under the app's support directory.
class FileMurottalStore implements MurottalStore {
  FileMurottalStore({Future<Directory> Function()? baseDir})
    : _baseDir = baseDir ?? _defaultDir;

  static Future<Directory> _defaultDir() async =>
      Directory('${(await getApplicationSupportDirectory()).path}/murottal');

  final Future<Directory> Function() _baseDir;
  Directory? _root;
  bool _unavailable = false;

  Future<Directory?> _dir() async {
    if (_unavailable) return null;
    try {
      return _root ??= await _baseDir();
    } catch (_) {
      _unavailable = true; // e.g. no path_provider in tests
      return null;
    }
  }

  Future<File?> _file(Reciter reciter, int ayahId) async {
    final dir = await _dir();
    if (dir == null) return null;
    return File('${dir.path}/${MurottalStore.relativePath(reciter, ayahId)}');
  }

  @override
  Future<bool> has(Reciter reciter, int ayahId) async =>
      await (await _file(reciter, ayahId))?.exists() ?? false;

  @override
  Future<String?> url(Reciter reciter, int ayahId) async {
    final file = await _file(reciter, ayahId);
    if (file == null || !await file.exists()) return null;
    return file.uri.toString();
  }

  @override
  Future<void> write(Reciter reciter, int ayahId, List<int> bytes) async {
    final file = await _file(reciter, ayahId);
    if (file == null) return;
    await file.parent.create(recursive: true);
    final tmp = File('${file.path}.part');
    await tmp.writeAsBytes(bytes, flush: true);
    await tmp.rename(file.path);
  }

  @override
  Future<void> delete(Reciter reciter, Iterable<int> ayahIds) async {
    for (final id in ayahIds) {
      final file = await _file(reciter, id);
      if (file != null && await file.exists()) await file.delete();
    }
  }

  @override
  Future<void> deleteAll() async {
    final dir = await _dir();
    if (dir != null && await dir.exists()) await dir.delete(recursive: true);
  }

  Future<List<File>> _all() async {
    final dir = await _dir();
    if (dir == null || !await dir.exists()) return const [];
    return [
      await for (final e in dir.list(recursive: true))
        if (e is File && e.path.endsWith('.mp3')) e,
    ];
  }

  @override
  Future<int> count() async => (await _all()).length;

  @override
  Future<int> bytes() async {
    var total = 0;
    for (final f in await _all()) {
      total += await f.length();
    }
    return total;
  }

  @override
  Future<int> bytesOf(Reciter reciter, Iterable<int> ayahIds) async {
    var total = 0;
    for (final id in ayahIds) {
      final file = await _file(reciter, id);
      if (file != null && await file.exists()) total += await file.length();
    }
    return total;
  }
}

/// In-memory store for tests.
class MemoryMurottalStore implements MurottalStore {
  final Map<String, List<int>> files = {};

  @override
  Future<bool> has(Reciter reciter, int ayahId) async =>
      files.containsKey(MurottalStore.relativePath(reciter, ayahId));

  @override
  Future<String?> url(Reciter reciter, int ayahId) async =>
      await has(reciter, ayahId)
      ? 'file:///murottal/${MurottalStore.relativePath(reciter, ayahId)}'
      : null;

  @override
  Future<void> write(Reciter reciter, int ayahId, List<int> bytes) async {
    files[MurottalStore.relativePath(reciter, ayahId)] = List.of(bytes);
  }

  @override
  Future<void> delete(Reciter reciter, Iterable<int> ayahIds) async {
    for (final id in ayahIds) {
      files.remove(MurottalStore.relativePath(reciter, id));
    }
  }

  @override
  Future<void> deleteAll() async => files.clear();

  @override
  Future<int> count() async => files.length;

  @override
  Future<int> bytes() async =>
      files.values.fold<int>(0, (sum, bytes) => sum + bytes.length);

  @override
  Future<int> bytesOf(Reciter reciter, Iterable<int> ayahIds) async {
    var total = 0;
    for (final id in ayahIds) {
      total += files[MurottalStore.relativePath(reciter, id)]?.length ?? 0;
    }
    return total;
  }
}

final murottalStoreProvider = Provider<MurottalStore>(
  (ref) => FileMurottalStore(),
);
