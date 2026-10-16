import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:tg_cine/data/repositories/sqlite_media_repository.dart';
import 'package:tg_cine/domain/models/media_organization.dart';
import 'package:tg_cine/domain/models/media_work.dart';

// Real imported metadata in a private encrypted copy. The live library is read-only.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'real imported metadata retains manual organization on repeat and reopen',
    (tester) async {
      final support = await getApplicationSupportDirectory();
      final original = File('${support.path}/media/primary/media.db');
      expect(await original.exists(), isTrue);
      final originalBytes = await original.readAsBytes();
      final encoded = await const FlutterSecureStorage().read(
        key: 'tg-cine.media.primary.database-key.v1',
      );
      expect(encoded != null, isTrue);
      final key = base64Decode(encoded!);
      final directory = await Directory.systemTemp.createTemp(
        'tg-cine-real-organization-',
      );
      final copy = await original.copy('${directory.path}/media.db');
      final db = sqlite3.open(copy.path);
      late int account;
      try {
        db.execute("PRAGMA key = '${base64Encode(key)}'");
        final rows = db.select(
          'SELECT DISTINCT account_id FROM sources WHERE selected=1',
        );
        expect(rows.isNotEmpty, isTrue);
        account = rows.first['account_id'] as int;
      } finally {
        db.close();
      }
      var store = SqliteMediaRepository.open(copy.path, key);
      try {
        final files = await store.loadMedia(account, limit: 200);
        expect(files.isNotEmpty, isTrue);
        final media = files.first;
        final progress = await store.loadProgress(account, media.versionKey);
        var cp = await store.checkpoint(account, media.sourceId);
        if (cp.paused) {
          cp = await store.setPaused(
            account,
            media.sourceId,
            false,
            expectedRevision: cp.revision,
          );
        }
        const title = 'Acceptance temporary organization';
        await store.saveOrganization(
          account,
          media.versionKey,
          const MediaOrganization(
            title: title,
            kind: MediaKind.movie,
            year: 2024,
            manual: true,
          ),
        );
        await store.writeBatch(
          account,
          media.sourceId,
          [media],
          nextMessageId: cp.nextMessageId,
          expectedRevision: cp.revision,
          complete: cp.complete,
        );
        await store.assignWork(
          account,
          const MediaWork(title: title, kind: MediaKind.movie, year: 2024),
          [WorkFileEdit(media.versionKey)],
        );
        await store.close();
        store = SqliteMediaRepository.open(copy.path, key);
        final grouped = (await store.loadWorks(
          account,
          query: title,
        )).where((w) => w.title == title).toList();
        expect(grouped.isNotEmpty, isTrue);
        final organized = (await store.loadVersions(
          account,
          media.sourceId,
          media.messageId,
        )).firstWhere((f) => f.versionKey == media.versionKey);
        expect(organized.organization.manual, isTrue);
        expect(organized.organization.title == title, isTrue);
        await store.unassignWork(account, [media.versionKey]);
        cp = await store.checkpoint(account, media.sourceId);
        await store.writeBatch(
          account,
          media.sourceId,
          [media],
          nextMessageId: cp.nextMessageId,
          expectedRevision: cp.revision,
          complete: cp.complete,
        );
        await store.close();
        store = SqliteMediaRepository.open(copy.path, key);
        for (final group in grouped) {
          expect(
            (await store.loadWorkFiles(
              account,
              group.id,
            )).any((f) => f.versionKey == media.versionKey),
            isFalse,
          );
        }
        expect(
          await store.loadProgress(account, media.versionKey) == progress,
          isTrue,
        );
        expect(
          (await store.loadMedia(account, limit: 200)).length,
          files.length,
        );
        debugPrint(
          'Real metadata copy: manual/reimport/group/detach/reopen passed; live library unchanged.',
        );
      } finally {
        await store.close();
        // Delete only this test-created private temporary directory.
        await directory.delete(recursive: true);
        expect(
          listEquals(await original.readAsBytes(), originalBytes),
          isTrue,
          reason: 'Live encrypted library must remain byte-for-byte unchanged',
        );
      }
    },
    skip: !Platform.isAndroid,
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
