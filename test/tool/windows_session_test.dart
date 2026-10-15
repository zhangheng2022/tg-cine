import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/support/windows_session.dart';

void main() {
  test(
    'DPAPI key survives reopening; corrupt or missing keys are preserved',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'tg-cine-session-test-',
      );
      final directory = Directory.fromUri(root.uri.resolve('account/'));
      final script = File('tool/support/private_directory.ps1');
      addTearDown(() async {
        // This exact root was created by this test, never an existing account.
        final resolved = await root.resolveSymbolicLinks();
        final temp = await Directory.systemTemp.resolveSymbolicLinks();
        if (Directory(resolved).parent.path != temp ||
            !resolved.startsWith(
              '$temp${Platform.pathSeparator}tg-cine-session-test-',
            )) {
          throw StateError('Unexpected temporary session path');
        }
        await root.delete(recursive: true);
      });
      final first = await WindowsSession.open(
        directory,
        permissionsScript: script,
      );
      final key = first.key.toList();
      await expectLater(
        WindowsSession.open(directory, permissionsScript: script),
        throwsA(isA<FileSystemException>()),
      );
      final keyFile = File.fromUri(directory.uri.resolve('key.dpapi'));
      final encrypted = await keyFile.readAsBytes();
      expect(encrypted, isNot(key));
      final database = File.fromUri(directory.uri.resolve('td.binlog'));
      await database.writeAsBytes([1, 2, 3]);
      await first.close();
      expect(first.key, everyElement(0));

      final second = await WindowsSession.open(
        directory,
        permissionsScript: script,
      );
      expect(second.key, key);
      await second.close();

      await keyFile.writeAsBytes([1, 2, 3]);
      await expectLater(
        WindowsSession.open(directory, permissionsScript: script),
        throwsStateError,
      );
      expect(await keyFile.readAsBytes(), [1, 2, 3]);
      await keyFile.delete();
      await expectLater(
        WindowsSession.open(directory, permissionsScript: script),
        throwsStateError,
      );
      expect(await keyFile.exists(), isFalse);
      expect(await database.readAsBytes(), [1, 2, 3]);
    },
    skip: !Platform.isWindows,
    timeout: const Timeout(Duration(seconds: 20)),
  );
}
