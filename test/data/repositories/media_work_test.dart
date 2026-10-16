import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:tg_cine/data/repositories/sqlite_media_repository.dart';
import 'package:tg_cine/domain/models/local_media.dart';
import 'package:tg_cine/domain/models/media_organization.dart';
import 'package:tg_cine/domain/models/media_work.dart';

void main() {
  late Directory dir;
  late SqliteMediaRepository store;
  final key = List.generate(32, (i) => i + 1);
  LocalMedia file(int id, String name) => LocalMedia(
    sourceId: -1,
    messageId: id,
    remoteUniqueId: 'file-$id',
    sizeBytes: 1024,
    fileName: name,
    sentAt: id,
  );
  Future<void> seed(List<LocalMedia> files, {int account = 1}) async {
    await store.saveSources(account, {-1});
    final cp = await store.checkpoint(account, -1);
    await store.writeBatch(
      account,
      -1,
      files,
      nextMessageId: 1,
      expectedRevision: cp.revision,
    );
  }

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('tg-cine-works-');
    store = SqliteMediaRepository.open('${dir.path}/media.db', key);
  });
  tearDown(() async {
    await store.close();
    // Only this test-created directory is removed.
    await dir.delete(recursive: true);
  });
  test(
    'work progress and next episode cross pages without merging versions',
    () async {
      final files = [
        for (var i = 1; i <= 55; i++) file(i, 'Show.S01E01.$i.mp4'),
        file(56, 'Show.S01E03.a.mp4'),
        file(57, 'Show.S01E03.b.mp4'),
        file(58, 'Show.S02E01.mp4'),
        file(59, 'Other.2024.mp4'),
      ];
      await seed(files);
      final work = (await store.loadWorks(1))
          .firstWhere((w) => w.kind == MediaKind.series);
      await store.saveProgress(
        1,
        files.first.versionKey,
        const Duration(minutes: 3),
      );
      await store.saveProgress(
        1,
        files[55].versionKey,
        const Duration(minutes: 20),
        completed: true,
      );
      await store.saveProgress(
        1,
        files.last.versionKey,
        const Duration(minutes: 8),
      );
      final recent = await store.loadHistory(
        1,
        workId: work.id,
        unfinished: true,
        limit: 1,
      );
      expect(recent.single.media.versionKey, files.first.versionKey);
      final statuses = await store.loadHistory(
        1,
        workId: work.id,
        versionKeys: [files[55].versionKey],
      );
      expect(statuses.single.completed, isTrue);
      expect(await store.loadHistory(2, workId: work.id), isEmpty);
      final next = await store.loadWorkFiles(
        1,
        work.id,
        nextAfter: files.first.versionKey,
      );
      expect(next.map((f) => f.messageId), [56, 57]);
      expect(
        (await store.loadWorkFiles(
          1,
          work.id,
          nextAfter: files.first.versionKey,
          offset: 1,
          limit: 1,
        )).single.messageId,
        57,
      );
      expect(
        (await store.loadWorkFiles(
          1,
          work.id,
          nextAfter: files[55].versionKey,
        )).single.messageId,
        58,
      );
      expect(
        await store.loadWorkFiles(1, work.id, nextAfter: files[57].versionKey),
        isEmpty,
      );
      await expectLater(
        store.loadWorkFiles(1, work.id, nextAfter: files.last.versionKey),
        throwsA(isA<LocalMediaException>()),
      );
      await store.saveSources(1, {});
      expect(await store.loadHistory(1, workId: work.id), isEmpty);
      await expectLater(
        store.loadWorkFiles(1, work.id, nextAfter: files.first.versionKey),
        throwsA(isA<LocalMediaException>()),
      );
    },
  );
  test('v6 upgrade groups by kind/title/year without changing versions or progress', () async {
    final files = [
      file(1, 'Film.2020.mp4'),
      file(2, 'Film.2020.mkv'),
      file(3, 'Film.2021.mp4'),
      file(4, 'Show.S02E03.mp4'),
      file(5, 'Show.S01E09.mp4'),
      file(6, 'unknown.mp4'),
    ];
    await seed(files);
    await store.saveProgress(
      1,
      files.first.versionKey,
      const Duration(seconds: 27),
    );
    await store.close();
    final db = sqlite3.open('${dir.path}/media.db');
    db.execute("PRAGMA key = '${base64Encode(key)}'");
    db.execute('DROP TABLE work_members; DROP TABLE works;');
    db.userVersion = 6;
    db.close();
    store = SqliteMediaRepository.open('${dir.path}/media.db', key);
    final works = await store.loadWorks(1);
    expect(works, hasLength(3));
    expect(works.firstWhere((w) => w.year == 2020).fileCount, 2);
    final series = works.firstWhere((w) => w.kind == MediaKind.series);
    expect((await store.loadWorkFiles(1, series.id)).map((f) => f.messageId), [
      5,
      4,
    ]);
    expect(
      await store.loadProgress(1, files.first.versionKey),
      const Duration(seconds: 27),
    );
    expect(await store.loadMedia(1), hasLength(6));
    expect(await store.loadWorks(2), isEmpty);
    await store.assignWork(1, works.firstWhere((w) => w.year == 2020), [
      WorkFileEdit(files.last.versionKey),
    ]);
    expect(
      (await store.loadWorks(1)).firstWhere((w) => w.year == 2020).fileCount,
      3,
    );
  });
  test('manual grouping, split and detach survive import and restart; batches roll back', () async {
    final a = file(1, 'unknown.mp4'), b = file(2, 'unknown2.mp4');
    await seed([a, b]);
    await store.saveProgress(1, a.versionKey, const Duration(seconds: 15));
    const work = MediaWork(
      title: 'Confirmed',
      kind: MediaKind.series,
      year: 2024,
    );
    await expectLater(
      store.assignWork(1, work, [
        WorkFileEdit(a.versionKey, season: 1, episode: 1),
        WorkFileEdit(b.versionKey, season: 1, episode: 0),
      ]),
      throwsA(isA<LocalMediaException>()),
    );
    expect(await store.loadWorks(1), isEmpty);
    expect(
      (await store.loadMedia(1)).every((f) => !f.organization.manual),
      isTrue,
    );
    await store.assignWork(1, work, [
      WorkFileEdit(a.versionKey, season: 1, episode: 3),
      WorkFileEdit(b.versionKey, season: 1, episode: 3),
    ]);
    final existing = (await store.loadWorks(1)).single;
    expect(existing.fileCount, 2);
    await seed([a, b]);
    expect((await store.loadWorks(1)).single.id, existing.id);
    await store.assignWork(1, work, [
      WorkFileEdit(b.versionKey, season: 2, episode: 1),
    ]);
    expect(await store.loadWorks(1), hasLength(2));
    await expectLater(
      store.unassignWork(1, [a.versionKey, 'missing']),
      throwsA(isA<LocalMediaException>()),
    );
    expect(
      (await store.loadWorkFiles(1, existing.id)).single.versionKey,
      a.versionKey,
    );
    await store.unassignWork(1, [a.versionKey]);
    await seed([a, b]);
    await store.close();
    store = SqliteMediaRepository.open('${dir.path}/media.db', key);
    expect(await store.loadWorkFiles(1, existing.id), isEmpty);
    expect(
      await store.loadProgress(1, a.versionKey),
      const Duration(seconds: 15),
    );
    expect(
      (await store.loadMedia(1))
          .firstWhere((f) => f.versionKey == a.versionKey)
          .organization
          .manual,
      isTrue,
    );
    await store.saveOrganization(
      1,
      b.versionKey,
      const MediaOrganization(
        title: 'Another movie',
        kind: MediaKind.movie,
        year: 2025,
      ),
    );
    expect(await store.loadWorks(1), isEmpty);
    await seed([a], account: 2);
    await expectLater(
      store.assignWork(2, existing, [
        WorkFileEdit(a.versionKey, season: 1, episode: 1),
      ]),
      throwsA(isA<LocalMediaException>()),
    );
    await store.saveSources(1, {});
    await expectLater(
      store.assignWork(1, work, [
        WorkFileEdit(a.versionKey, season: 1, episode: 1),
      ]),
      throwsA(isA<LocalMediaException>()),
    );
  });
  test(
    'work counts and file pagination include only selected current versions',
    () async {
      final files = List.generate(55, (i) => file(i + 1, 'Film.2020.mp4'));
      await seed(files);
      final work = (await store.loadWorks(1)).single;
      expect(work.fileCount, 55);
      expect(await store.loadWorkFiles(1, work.id), hasLength(50));
      expect(await store.loadWorkFiles(1, work.id, offset: 50), hasLength(5));
      final replacement = LocalMedia(
        sourceId: -1,
        messageId: 1,
        remoteUniqueId: 'new',
        sizeBytes: 22,
        fileName: 'unknown.mp4',
      );
      await seed([replacement]);
      expect((await store.loadWorks(1)).single.fileCount, 54);
      await expectLater(
        store.assignWork(1, work, [WorkFileEdit(files.first.versionKey)]),
        throwsA(isA<LocalMediaException>()),
      );
      await store.saveSources(1, {});
      expect(await store.loadWorks(1), isEmpty);
    },
  );
}
