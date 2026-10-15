import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tg_cine/data/services/telegram/windows_session.dart';
import 'package:tg_cine/data/services/telegram/windows_source_store.dart';

void main() {
  test(
    'DPAPI selections reopen, isolate accounts and preserve corrupt bytes',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'tg-cine-sources-',
      );
      try {
        final session = await WindowsSession.open(
          directory,
          permissionsScript: File('tool/support/private_directory.ps1'),
        );
        final store = WindowsSourceStore(directory);
        await store.write(100, {-1, -2});
        final file = File.fromUri(directory.uri.resolve('sources-100.dpapi'));
        expect(
          await file.readAsString().catchError((Object _) => ''),
          isNot(contains('accountId')),
        );
        expect(await store.read(100), {-1, -2});
        expect(await store.read(200), isEmpty);
        await store.write(100, {-2});
        expect(await File('${file.path}.bak').exists(), isTrue);
        await file.writeAsBytes([1, 2, 3]);
        await expectLater(store.read(100), throwsStateError);
        expect(await file.readAsBytes(), [1, 2, 3]);
        await session.close();
      } finally {
        final resolved = await directory.resolveSymbolicLinks();
        final temp = await Directory.systemTemp.resolveSymbolicLinks();
        if (Directory(resolved).parent.path != temp ||
            !directory.path
                .split(Platform.pathSeparator)
                .last
                .startsWith('tg-cine-sources-')) {
          throw StateError('Unexpected temporary directory');
        }
        await directory.delete(recursive: true);
      }
    },
    skip: !Platform.isWindows,
  );
}
