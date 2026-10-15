import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:tg_cine/data/repositories/sqlite_media_repository.dart';
import 'package:tg_cine/data/services/telegram/mobile_session.dart';
import 'package:tg_cine/data/services/telegram/windows_session.dart';
import 'package:tg_cine/domain/models/local_media.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'native encrypted media database and platform key survive reopening',
    (tester) async {
      final parent = Platform.isWindows
          ? Directory.systemTemp
          : await getApplicationSupportDirectory();
      final directory = await parent.createTemp('tg-cine-media-acceptance-');
      final keyName =
          'tg-cine.acceptance.media.${DateTime.now().microsecondsSinceEpoch}';
      const storage = FlutterSecureStorage(
        iOptions: IOSOptions(
          accessibility: KeychainAccessibility.first_unlock_this_device,
        ),
      );
      MobileSession? mobile;
      WindowsSession? windows;
      SqliteMediaRepository? repository;
      Future<Uint8List> openKey() async {
        if (Platform.isWindows) {
          windows = await WindowsSession.open(
            directory,
            permissionsScript: File(
              const String.fromEnvironment(
                'TG_CINE_PRIVATE_DIRECTORY_SCRIPT',
                defaultValue: 'tool/support/private_directory.ps1',
              ),
            ),
          );
          return windows!.key;
        }
        mobile = await MobileSession.open(directory, storage, keyName: keyName);
        return mobile!.key;
      }

      Future<void> close() async {
        try {
          await repository?.close();
        } finally {
          repository = null;
          await mobile?.close();
          mobile = null;
          await windows?.close();
          windows = null;
        }
      }

      try {
        if (Platform.isIOS) {
          await const MethodChannel('io.tgcine/native')
              .invokeMethod<void>('excludeFromBackup', directory.path);
        }
        final path = p.join(directory.path, 'media.db');
        repository = SqliteMediaRepository.open(path, await openKey());
        const item = LocalMedia(
          sourceId: -1,
          messageId: 10,
          remoteUniqueId: 'acceptance-only',
          sizeBytes: 1024,
          fileName: 'design-data.mp4',
        );
        await repository!.restoreSources(100, (_) async => {-1});
        await repository!.writeBatch(
          100,
          -1,
          [item],
          nextMessageId: 10,
          expectedRevision: 0,
        );
        await repository!.saveProgress(
          100,
          item.versionKey,
          const Duration(seconds: 12),
        );
        await close();
        repository = SqliteMediaRepository.open(path, await openKey());
        expect(await repository!.readSources(100), {-1});
        expect(
          (await repository!.loadMedia(100)).single.versionKey,
          item.versionKey,
        );
        expect((await repository!.checkpoint(100, -1)).nextMessageId, 10);
        expect(
          await repository!.loadProgress(100, item.versionKey),
          const Duration(seconds: 12),
        );
        expect(await repository!.loadMedia(200), isEmpty);
      } finally {
        await close();
        if (!Platform.isWindows) await storage.delete(key: keyName);
        final resolved = await directory.resolveSymbolicLinks();
        final temp = await parent.resolveSymbolicLinks();
        if (p.dirname(resolved) != temp ||
            !p.basename(resolved).startsWith('tg-cine-media-acceptance-')) {
          throw StateError('Unexpected temporary acceptance directory');
        }
        await directory.delete(recursive: true);
      }
    },
    skip: !(Platform.isWindows || Platform.isAndroid || Platform.isIOS),
  );
}
