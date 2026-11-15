import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the dependency rules of docs/ARCHITECTURE.md:
///
/// - `core/` knows nothing about the app: no `shared/`, `features/`, `app/`.
/// - `shared/` may use `core/` only.
/// - `features/` never import `app/`.
/// - `domain/` code is plain Dart: no Flutter, Riverpod or I/O packages.
void main() {
  final import = RegExp(r"""^import\s+'([^']+)'""", multiLine: true);

  Map<String, List<String>> importsUnder(String dir) => {
    for (final file in Directory('lib/$dir').listSync(recursive: true))
      if (file is File && file.path.endsWith('.dart'))
        file.path: [
          for (final m in import.allMatches(file.readAsStringSync()))
            m.group(1)!,
        ],
  };

  List<String> offending(String dir, bool Function(String uri) forbidden) => [
    for (final entry in importsUnder(dir).entries)
      for (final uri in entry.value)
        if (forbidden(uri)) '${entry.key} imports $uri',
  ];

  test('core does not depend on shared, features or app', () {
    expect(
      offending(
        'core',
        (uri) =>
            uri.startsWith('package:muslimku/shared/') ||
            uri.startsWith('package:muslimku/features/') ||
            uri.startsWith('package:muslimku/app/'),
      ),
      isEmpty,
    );
  });

  test('shared depends on core only', () {
    expect(
      offending(
        'shared',
        (uri) =>
            uri.startsWith('package:muslimku/features/') ||
            uri.startsWith('package:muslimku/app/'),
      ),
      isEmpty,
    );
  });

  test('features do not depend on the app shell', () {
    expect(
      offending('features', (uri) => uri.startsWith('package:muslimku/app/')),
      isEmpty,
    );
  });

  test('domain code is plain Dart', () {
    const allowed = ['dart:', 'package:muslimku/', 'package:intl/'];
    final domainFiles = importsUnder(
      'features',
    ).entries.where((e) => e.key.contains('/domain/'));
    expect(domainFiles, isNotEmpty);
    expect([
      for (final entry in domainFiles)
        for (final uri in entry.value)
          if (!allowed.any(uri.startsWith)) '${entry.key} imports $uri',
    ], isEmpty);
  });
}
