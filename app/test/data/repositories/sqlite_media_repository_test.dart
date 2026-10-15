import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';
import 'package:tg_cine/data/repositories/sqlite_media_repository.dart';
import 'package:tg_cine/domain/models/local_media.dart';

void main() {
  late Directory directory;
  late String path;
  late SqliteMediaRepository repository;
  var closed = false;
  final key = List.generate(32, (index) => index + 1);
  LocalMedia sample({
    int source = -1,
    int message = 10,
    String remote = 'stable-file-a',
    String name = 'original.mp4',
    int size = 1024,
  }) => LocalMedia(
    sourceId: source,
    messageId: message,
    remoteUniqueId: remote,
    sizeBytes: size,
    fileName: name,
    caption: 'private-media-caption',
    durationSeconds: 60,
    sentAt: message,
  );
  Matcher failure(LocalMediaFailure kind) => isA<LocalMediaException>().having(
    (error) => error.failure,
    'failure',
    kind,
  );
  Future<void> batch(int account, LocalMedia item, {int revision = 0}) =>
      repository.writeBatch(
        account,
        item.sourceId,
        [item],
        nextMessageId: item.messageId,
        expectedRevision: revision,
      );

  setUp(() async {
    closed = false;
    directory = await Directory.systemTemp.createTemp('tg-cine-media-test-');
    path = p.join(directory.path, 'media.db');
    repository = SqliteMediaRepository.open(path, key);
  });
  tearDown(() async {
    if (!closed) await repository.close();
    final resolved = await directory.resolveSymbolicLinks();
    final temp = await Directory.systemTemp.resolveSymbolicLinks();
    if (p.dirname(resolved) != temp ||
        !p.basename(resolved).startsWith('tg-cine-media-test-')) {
      throw StateError('Unexpected temporary test directory');
    }
    await directory.delete(recursive: true);
  });

  test('encrypted media, selections, checkpoint and version progress survive reopening', () async {
    await repository.saveSources(100, {-1});
    await batch(100, sample());
    await repository.saveProgress(
      100,
      sample().versionKey,
      const Duration(seconds: 12),
    );
    await repository.close();
    closed = true;
    final bytes = await File(path).readAsBytes();
    final raw = latin1.decode(bytes);
    expect(raw.startsWith('SQLite format 3'), isFalse);
    expect(raw.contains('private-media-caption'), isFalse);
    expect(raw.contains('original.mp4'), isFalse);
    repository = SqliteMediaRepository.open(path, key);
    closed = false;
    expect(await repository.readSources(100), {-1});
    expect(
      (await repository.loadMedia(100)).single.versionKey,
      sample().versionKey,
    );
    expect((await repository.checkpoint(100, -1)).nextMessageId, 10);
    expect(
      await repository.loadProgress(100, sample().versionKey),
      const Duration(seconds: 12),
    );
  });

  test(
    'wrong key, corrupt data and newer schemas fail without replacing files',
    () async {
      await repository.saveSources(100, {-1});
      await repository.close();
      closed = true;
      final saved = await File(path).readAsBytes();
      expect(
        () => SqliteMediaRepository.open(path, List.filled(32, 99)),
        throwsA(failure(LocalMediaFailure.storage)),
      );
      expect(await File(path).readAsBytes(), saved);
      final db = sqlite3.open(path)
        ..execute("PRAGMA key = '${base64Encode(key)}'");
      db.userVersion = 99;
      db.close();
      final newer = await File(path).readAsBytes();
      expect(
        () => SqliteMediaRepository.open(path, key),
        throwsA(failure(LocalMediaFailure.storage)),
      );
      expect(await File(path).readAsBytes(), newer);
      await File(path).writeAsBytes([1, 2, 3], flush: true);
      expect(
        () => SqliteMediaRepository.open(path, key),
        throwsA(failure(LocalMediaFailure.storage)),
      );
      expect(await File(path).readAsBytes(), [1, 2, 3]);
    },
  );

  test(
    'v1 to current schema migration keeps existing selections and versions',
    () async {
      await repository.saveSources(100, {-1});
      await batch(100, sample());
      await repository.close();
      closed = true;
      final db = sqlite3.open(path)
        ..execute("PRAGMA key = '${base64Encode(key)}'");
      db.execute('DROP TABLE playback_progress');
      db.execute('ALTER TABLE sources DROP COLUMN title');
      db.userVersion = 1;
      db.close();
      repository = SqliteMediaRepository.open(path, key);
      closed = false;
      expect(await repository.readSources(100), {-1});
      expect((await repository.loadMedia(100)).single.fileName, 'original.mp4');
      await repository.saveProgress(
        100,
        sample().versionKey,
        const Duration(seconds: 4),
      );
      expect(
        await repository.loadProgress(100, sample().versionKey),
        const Duration(seconds: 4),
      );
    },
  );

  test('v2 source-title migration preserves progress and supports literal account-scoped search', () async {
    await repository.saveSources(100, {-1});
    await batch(100, sample());
    await repository.saveProgress(
      100,
      sample().versionKey,
      const Duration(seconds: 12),
    );
    await repository.close();
    closed = true;
    final db = sqlite3.open(path)
      ..execute("PRAGMA key = '${base64Encode(key)}'");
    db.execute('ALTER TABLE sources DROP COLUMN title');
    db.userVersion = 2;
    db.close();
    repository = SqliteMediaRepository.open(path, key);
    closed = false;
    await repository.describeSources(100, {-1: '私人来源 100%'});
    expect((await repository.loadImports(100)).single.imported, 1);
    expect(await repository.loadMedia(100, query: '100%'), hasLength(1));
    expect(await repository.loadMedia(100, query: 'OR 1=1'), isEmpty);
    expect(await repository.loadMedia(200, query: '私人来源'), isEmpty);
    expect(
      await repository.loadProgress(100, sample().versionKey),
      const Duration(seconds: 12),
    );
  });

  test('legacy migration retries failures, runs once per account and respects concurrent saves', () async {
    var calls = 0;
    Future<Set<int>> legacy(int _) async {
      calls++;
      return {-1};
    }

    await expectLater(
      repository.restoreSources(
        100,
        (_) async => throw StateError('vault unavailable'),
      ),
      throwsA(failure(LocalMediaFailure.storage)),
    );
    expect(await repository.restoreSources(100, legacy), {-1});
    expect(await repository.restoreSources(100, legacy), {-1});
    expect(calls, 1);
    final pending = Completer<Set<int>>();
    final migration = repository.restoreSources(200, (_) => pending.future);
    await repository.saveSources(200, {-2});
    pending.complete({-1});
    expect(await migration, {-2});
    expect(await repository.readSources(100), {-1});
  });

  test(
    'failed migration rolls back its schema version and keeps records',
    () async {
      await repository.saveSources(100, {-1});
      await repository.close();
      closed = true;
      final db = sqlite3.open(path)
        ..execute("PRAGMA key = '${base64Encode(key)}'");
      // A conflicting v2 table simulates a failed upgrade from an existing v1 file.
      db.userVersion = 1;
      db.close();
      expect(
        () => SqliteMediaRepository.open(path, key),
        throwsA(failure(LocalMediaFailure.storage)),
      );
      final preserved = sqlite3.open(path)
        ..execute("PRAGMA key = '${base64Encode(key)}'");
      expect(preserved.userVersion, 1);
      expect(preserved.select('SELECT id FROM sources').single['id'], -1);
      preserved.close();
    },
  );

  test('deselection or removal followed by reselect rejects a pending initial batch', () async {
    await repository.saveSources(100, {-1});
    await repository.saveSources(100, {});
    await repository.saveSources(100, {-1});
    await expectLater(
      batch(100, sample()),
      throwsA(failure(LocalMediaFailure.conflict)),
    );
    final current = await repository.checkpoint(100, -1);
    await batch(100, sample(), revision: current.revision);
    await repository.removeSource(100, -1);
    await repository.saveSources(100, {-1});
    await expectLater(
      batch(100, sample(message: 20), revision: current.revision + 1),
      throwsA(failure(LocalMediaFailure.conflict)),
    );
    expect(await repository.loadMedia(100), isEmpty);
  });

  test(
    'account isolation applies to sources, media, checkpoints and progress',
    () async {
      await repository.saveSources(100, {-1});
      await repository.saveSources(200, {-2});
      await batch(100, sample());
      expect(await repository.readSources(200), {-2});
      expect(await repository.loadMedia(200), isEmpty);
      expect((await repository.checkpoint(200, -1)).revision, 0);
      await expectLater(
        batch(200, sample()),
        throwsA(failure(LocalMediaFailure.conflict)),
      );
      await expectLater(
        repository.saveProgress(
          200,
          sample().versionKey,
          const Duration(seconds: 1),
        ),
        throwsA(failure(LocalMediaFailure.storage)),
      );
      expect(await repository.loadProgress(100, sample().versionKey), isNull);
      await repository.saveSources(200, {-1, -2});
      await batch(200, sample(name: 'other-account.mp4'));
      await repository.saveProgress(
        200,
        sample().versionKey,
        const Duration(seconds: 3),
      );
      expect((await repository.loadMedia(100)).single.fileName, 'original.mp4');
      expect(await repository.loadProgress(100, sample().versionKey), isNull);
    },
  );

  test('repeated scans update metadata, changed files retain separate versions and progress', () async {
    await repository.saveSources(100, {-1});
    await batch(100, sample());
    await repository.saveProgress(
      100,
      sample().versionKey,
      const Duration(seconds: 5),
    );
    await batch(100, sample(name: 'renamed.mp4'), revision: 1);
    expect((await repository.loadVersions(100, -1, 10)).length, 1);
    expect((await repository.loadMedia(100)).single.fileName, 'renamed.mp4');
    final replacement = sample(remote: 'stable-file-b');
    await batch(100, replacement, revision: 2);
    expect((await repository.loadVersions(100, -1, 10)).length, 2);
    expect(
      (await repository.loadMedia(100)).single.versionKey,
      replacement.versionKey,
    );
    expect(
      await repository.loadProgress(100, sample().versionKey),
      const Duration(seconds: 5),
    );
    expect(await repository.loadProgress(100, replacement.versionKey), isNull);
    await batch(100, sample(remote: 'stable-file-b', size: 2048), revision: 3);
    expect((await repository.loadVersions(100, -1, 10)).length, 3);
  });

  test(
    'invalid batch rolls back earlier records and checkpoint together',
    () async {
      await repository.saveSources(100, {-1});
      await batch(100, sample());
      await expectLater(
        repository.writeBatch(
          100,
          -1,
          [sample(message: 20), sample(source: -2, message: 30)],
          nextMessageId: 30,
          expectedRevision: 1,
        ),
        throwsA(failure(LocalMediaFailure.invalidInput)),
      );
      expect((await repository.loadMedia(100)).map((item) => item.messageId), [
        10,
      ]);
      expect((await repository.checkpoint(100, -1)).nextMessageId, 10);
      expect((await repository.checkpoint(100, -1)).revision, 1);
    },
  );

  test(
    'pause, resume, stale revisions and deselection block obsolete imports',
    () async {
      await repository.saveSources(100, {-1});
      await batch(100, sample());
      final paused = await repository.setPaused(
        100,
        -1,
        true,
        expectedRevision: 1,
      );
      expect(paused.nextMessageId, 10);
      await expectLater(
        batch(100, sample(message: 20), revision: paused.revision),
        throwsA(failure(LocalMediaFailure.conflict)),
      );
      final resumed = await repository.setPaused(
        100,
        -1,
        false,
        expectedRevision: paused.revision,
      );
      await expectLater(
        batch(100, sample(message: 20), revision: 1),
        throwsA(failure(LocalMediaFailure.conflict)),
      );
      final completed = await repository.writeBatch(
        100,
        -1,
        [],
        nextMessageId: 0,
        expectedRevision: resumed.revision,
        complete: true,
      );
      expect(completed.complete, isTrue);
      await repository.saveSources(100, {});
      expect(await repository.loadMedia(100), isEmpty);
      expect((await repository.loadVersions(100, -1, 10)).length, 1);
      await expectLater(
        batch(100, sample(message: 20), revision: completed.revision),
        throwsA(failure(LocalMediaFailure.conflict)),
      );
      await repository.saveSources(100, {-1});
      expect((await repository.loadMedia(100)).length, 1);
    },
  );

  test('removing one source preserves another source and account with the same file identity', () async {
    await repository.saveSources(100, {-1, -2});
    await repository.saveSources(200, {-1});
    await batch(100, sample());
    await batch(100, sample(source: -2));
    await batch(200, sample());
    await repository.saveProgress(
      100,
      sample().versionKey,
      const Duration(seconds: 8),
    );
    await repository.removeSource(100, -1);
    expect((await repository.loadMedia(100)).single.sourceId, -2);
    expect((await repository.loadMedia(200)).single.sourceId, -1);
    expect(await repository.loadVersions(100, -1, 10), isEmpty);
    expect(await repository.loadProgress(100, sample().versionKey), isNull);
    expect((await repository.checkpoint(100, -1)).revision, 2);
  });

  test(
    'pagination is bounded and deterministic without titles as identity',
    () async {
      await repository.saveSources(100, {-1});
      await repository.writeBatch(
        100,
        -1,
        [sample(message: 10), sample(message: 20)],
        nextMessageId: 20,
        expectedRevision: 0,
      );
      expect((await repository.loadMedia(100, limit: 1)).single.messageId, 20);
      expect(
        (await repository.loadMedia(100, offset: 1, limit: 1)).single.messageId,
        10,
      );
      await expectLater(
        repository.loadMedia(100, limit: 201),
        throwsA(failure(LocalMediaFailure.invalidInput)),
      );
      await expectLater(
        repository.saveSources(100, {0}),
        throwsA(failure(LocalMediaFailure.invalidInput)),
      );
      expect(await repository.readSources(100), {-1});
      await expectLater(
        repository.writeBatch(
          100,
          -1,
          List.filled(201, sample()),
          nextMessageId: 0,
          expectedRevision: 1,
        ),
        throwsA(failure(LocalMediaFailure.invalidInput)),
      );
      await expectLater(
        repository.saveProgress(
          100,
          sample().versionKey,
          const Duration(seconds: -1),
        ),
        throwsA(failure(LocalMediaFailure.invalidInput)),
      );
      expect(
        () => SqliteMediaRepository.open(path, [1, 2, 3]),
        throwsA(failure(LocalMediaFailure.invalidInput)),
      );
    },
  );
}
