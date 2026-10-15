import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tg_cine/data/services/telegram/mobile_session.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  const storage = FlutterSecureStorage();
  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    directory = await Directory.systemTemp.createTemp('tg-cine-mobile-vault-');
  });
  tearDown(() async {
    final path = await directory.resolveSymbolicLinks();
    final temp = await Directory.systemTemp.resolveSymbolicLinks();
    if (Directory(path).parent.path != temp ||
        !directory.path
            .split(Platform.pathSeparator)
            .last
            .startsWith('tg-cine-mobile-vault-')) {
      throw StateError('Unexpected temporary test directory');
    }
    await directory.delete(recursive: true);
  });

  test('mobile key and account-scoped selections survive reopening', () async {
    final first = await MobileSession.open(directory, storage);
    final key = first.key.toList();
    await first.writeSources(100, {-1, -2});
    expect(await first.readSources(200), isEmpty);
    await first.close();
    expect(first.key, everyElement(0));
    final second = await MobileSession.open(directory, storage);
    expect(second.key, key);
    expect(await second.readSources(100), {-1, -2});
    await second.close();
  });

  test('missing key never overwrites existing database', () async {
    final file = File.fromUri(directory.uri.resolve('td.binlog'));
    await file.writeAsBytes([1, 2, 3]);
    await expectLater(MobileSession.open(directory, storage), throwsStateError);
    expect(await file.readAsBytes(), [1, 2, 3]);
    expect(await storage.readAll(), isEmpty);
  });

  test(
    'media key is independent and a missing media key preserves its database',
    () async {
      const mediaKey = 'tg-cine.media.primary.database-key.v1';
      final telegram = await MobileSession.open(directory, storage);
      final telegramKey = telegram.key.toList();
      final mediaDirectory = Directory.fromUri(directory.uri.resolve('media/'));
      final media = await MobileSession.open(
        mediaDirectory,
        storage,
        keyName: mediaKey,
      );
      expect(media.key, isNot(telegramKey));
      final file = File.fromUri(mediaDirectory.uri.resolve('media.db'));
      await file.writeAsBytes([1, 2, 3]);
      await media.close();
      await telegram.close();
      await storage.delete(key: mediaKey);
      await expectLater(
        MobileSession.open(mediaDirectory, storage, keyName: mediaKey),
        throwsStateError,
      );
      expect(await file.readAsBytes(), [1, 2, 3]);
      expect(await storage.read(key: mediaKey), isNull);
      expect(
        await storage.read(key: 'tg-cine.telegram.primary.database-key.v1'),
        isNotNull,
      );
    },
  );

  test(
    'invalid key is preserved and source records cannot cross accounts',
    () async {
      const keyName = 'tg-cine.telegram.primary.database-key.v1';
      FlutterSecureStorage.setMockInitialValues({keyName: 'AQID'});
      await expectLater(
        MobileSession.open(directory, storage),
        throwsStateError,
      );
      expect(await storage.read(key: keyName), 'AQID');
      FlutterSecureStorage.setMockInitialValues({});
      final session = await MobileSession.open(directory, storage);
      await storage.write(
        key: 'tg-cine.telegram.100.sources.v1',
        value: '{"schema":1,"accountId":200,"ids":[-1]}',
      );
      await expectLater(session.readSources(100), throwsFormatException);
      await expectLater(session.writeSources(100, {0}), throwsFormatException);
      await session.close();
    },
  );
}
