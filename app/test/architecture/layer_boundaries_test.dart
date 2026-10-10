import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('imports preserve MVVM layer boundaries', () {
    final violations = <String>[];
    final lib = Directory('lib').absolute.uri;
    final directives = RegExp(
      r'''^\s*(?:import|export)\s+['"]([^'"]+)['"]''',
      multiLine: true,
    );

    for (final file in Directory(
      'lib',
    ).listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart')) continue;
      final sourceLayer = file.absolute.uri.path
          .substring(lib.path.length)
          .split('/')
          .first;
      for (final match in directives.allMatches(file.readAsStringSync())) {
        final uri = match.group(1)!;
        final target = uri.startsWith('package:tg_cine/')
            ? lib.resolve(uri.substring('package:tg_cine/'.length))
            : file.absolute.uri.resolve(uri);
        final targetLayer = target.path.startsWith(lib.path)
            ? target.path.substring(lib.path.length).split('/').first
            : null;

        final invalid = switch (sourceLayer) {
          'domain' => targetLayer != 'domain' && !uri.startsWith('dart:'),
          'data' =>
            targetLayer != null && !['data', 'domain'].contains(targetLayer),
          'ui' => ['app', 'data'].contains(targetLayer),
          'theme' || 'l10n' => ['app', 'ui', 'data'].contains(targetLayer),
          _ => false,
        };
        if (invalid) violations.add('${file.path}: $uri');
      }
    }

    expect(violations, isEmpty, reason: violations.join('\n'));
  });
}
