import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// `images/` is bundled into the app as a whole (pubspec: assets: - images/),
// so everything in it ships to every phone.
void main() {
  test('every image path referenced in lib/ exists', () {
    final reference = RegExp(r'''['"](images/[^'"]+)['"]''');
    final missing = <String>[];
    final dartFiles = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));
    for (final file in dartFiles) {
      for (final match in reference.allMatches(file.readAsStringSync())) {
        final path = match.group(1)!;
        if (!File(path).existsSync()) {
          missing.add('${file.path}: $path');
        }
      }
    }
    expect(missing, isEmpty);
  });

  test('bundled images stay under 2 MB in total', () {
    final totalBytes = Directory('images')
        .listSync(recursive: true)
        .whereType<File>()
        .fold<int>(0, (sum, file) => sum + file.lengthSync());
    expect(
      totalBytes,
      lessThan(2 * 1024 * 1024),
      reason: 'images/ is shipped inside the app; keep icons small (WebP).',
    );
  });

  test('every font file declared in pubspec.yaml exists', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    // Only real entries: the commented template lines start with '#'.
    final assets = RegExp(
      r'^\s+- asset: (fonts/\S+)',
      multiLine: true,
    ).allMatches(pubspec).map((m) => m.group(1)!).toList();
    expect(assets, hasLength(6));
    expect(assets, isNotEmpty);
    expect(assets.where((path) => !File(path).existsSync()), isEmpty);
    for (final family in ['PlusJakartaSans', 'Amiri']) {
      expect(pubspec, contains('- family: $family'));
    }
  });
}
