import 'package:tg_cine/domain/models/media_organization.dart';
import 'package:tg_cine/domain/models/watch_record.dart';
import 'package:tg_cine/domain/models/media_work.dart';

import 'dart:async';

import 'package:tg_cine/domain/models/local_media.dart';
import 'package:tg_cine/domain/models/telegram_account.dart';
import 'package:tg_cine/domain/ports/media_library_repository.dart';

class FakeMediaLibraryRepository implements MediaLibraryRepository {
  FakeMediaLibraryRepository({this.complete = true, bool empty = false}) {
    if (!empty) records.addAll(designMedia);
  }
  static const designMedia = [
    LocalMedia(
      sourceId: -1,
      messageId: 20,
      remoteUniqueId: 'design-20',
      sizeBytes: 50331648,
      fileName: '设计数据 · 山间散步.mp4',
      durationSeconds: 180,
      sentAt: 20,
      caption: '设计数据：个人拍摄的短片。所有画面信息仅用于界面验收。',
    ),
    LocalMedia(
      sourceId: -1,
      messageId: 10,
      remoteUniqueId: 'design-10',
      sizeBytes: 33554432,
      fileName: '设计数据 · 很长的中文文件名与_Original_Filename_用于测试完整文件信息和字体缩放.mkv',
      sentAt: 10,
    ),
  ];
  final List<LocalMedia> records = [];
  final List<MediaWork> grouped = [];
  final Map<String, int> membership = {};
  @override
  Future<List<MediaWork>> works({
    String query = '',
    int offset = 0,
    int limit = 50,
  }) async {
    if (fail) throw const TelegramException(TelegramFailure.storage);
    return grouped
        .where(
          (w) => w.title.contains(query) && membership.values.contains(w.id),
        )
        .skip(offset)
        .take(limit)
        .map(
          (w) => MediaWork(
            id: w.id,
            title: w.title,
            kind: w.kind,
            year: w.year,
            fileCount: membership.values.where((id) => id == w.id).length,
          ),
        )
        .toList();
  }

  @override
  Future<List<LocalMedia>> workFiles(
    int workId, {
    int offset = 0,
    int limit = 50,
    String? nextAfter,
  }) async {
    if (fail) throw const TelegramException(TelegramFailure.storage);
    var members = records
        .where((r) => membership[r.versionKey] == workId)
        .toList();
    if (nextAfter != null) {
      final current = members
          .firstWhere((m) => m.versionKey == nextAfter)
          .organization;
      members =
          members.where((m) {
            final o = m.organization;
            return o.season != null &&
                o.episode != null &&
                current.season != null &&
                current.episode != null &&
                (o.season! > current.season! ||
                    (o.season == current.season &&
                        o.episode! > current.episode!));
          }).toList()..sort((a, b) {
            final season = a.organization.season!.compareTo(
              b.organization.season!,
            );
            return season != 0
                ? season
                : a.organization.episode!.compareTo(b.organization.episode!);
          });
      if (members.isNotEmpty) {
        final next = members.first.organization;
        members = members
            .where(
              (m) =>
                  m.organization.season == next.season &&
                  m.organization.episode == next.episode,
            )
            .toList();
      }
    }
    return members.skip(offset).take(limit).toList();
  }

  @override
  Future<void> assignWork(MediaWork work, List<WorkFileEdit> files) async {
    if (fail) throw const TelegramException(TelegramFailure.storage);
    final id = work.id == 0 ? grouped.length + 1 : work.id;
    if (work.id == 0) {
      grouped.add(
        MediaWork(id: id, title: work.title, kind: work.kind, year: work.year),
      );
    }
    for (final file in files) {
      membership[file.versionKey] = id;
      await saveOrganization(
        records.firstWhere((r) => r.versionKey == file.versionKey),
        MediaOrganization(
          title: work.title,
          kind: work.kind,
          year: work.year,
          season: file.season,
          episode: file.episode,
          manual: true,
        ),
      );
    }
  }

  @override
  Future<void> unassignWork(List<String> versionKeys) async {
    if (fail) throw const TelegramException(TelegramFailure.storage);
    for (final key in versionKeys) {
      membership.remove(key);
    }
  }

  final List<WatchRecord> watched = [];
  @override
  Future<List<WatchRecord>> history({
    int offset = 0,
    int limit = 50,
    bool unfinished = false,
    int? workId,
    List<String>? versionKeys,
  }) async {
    if (fail) throw const TelegramException(TelegramFailure.storage);
    return watched
        .where(
          (r) =>
              workId == null ||
              (membership[r.media.versionKey] == workId && r.available),
        )
        .where(
          (r) =>
              versionKeys == null || versionKeys.contains(r.media.versionKey),
        )
        .where(
          (r) => !unfinished || (!r.completed && r.position > Duration.zero),
        )
        .skip(offset)
        .take(limit)
        .toList();
  }

  @override
  Future<void> removeHistory({String? versionKey}) async {
    if (fail) throw const TelegramException(TelegramFailure.storage);
    watched.removeWhere(
      (r) => versionKey == null || r.media.versionKey == versionKey,
    );
  }

  bool complete;
  bool paused = false;
  bool fail = false;
  bool linkSupported = true;
  int calls = 0;
  int revision = 0;
  Completer<void>? pending;
  Completer<void>? pendingPause;
  int pauseCalls = 0;

  @override
  Future<List<LocalMedia>> media({
    int offset = 0,
    int limit = 50,
    String query = '',
    MediaKind? kind,
  }) async {
    if (fail) throw const TelegramException(TelegramFailure.storage);
    return records
        .where((item) => kind == null || item.organization.kind == kind)
        .where(
          (item) =>
              item.fileName.contains(query) ||
              item.caption.contains(query) ||
              '设计数据 · 私人片库'.contains(query),
        )
        .skip(offset)
        .take(limit)
        .toList();
  }

  @override
  Future<void> saveOrganization(
    LocalMedia item,
    MediaOrganization? value,
  ) async {
    if (fail) throw const TelegramException(TelegramFailure.storage);
    final index = records.indexWhere(
      (row) => row.versionKey == item.versionKey,
    );
    records[index] = LocalMedia(
      sourceId: item.sourceId,
      messageId: item.messageId,
      remoteUniqueId: item.remoteUniqueId,
      sizeBytes: item.sizeBytes,
      fileName: item.fileName,
      durationSeconds: item.durationSeconds,
      caption: item.caption,
      sentAt: item.sentAt,
      organization: value,
    );
  }

  @override
  Future<List<SourceImport>> imports() async => [
    SourceImport(
      sourceId: -1,
      title: '设计数据 · 私人片库',
      imported: records.length,
      checkpoint: ImportCheckpoint(
        nextMessageId: complete ? 0 : 10,
        complete: complete,
        paused: paused,
        revision: revision,
      ),
    ),
  ];
  @override
  Future<void> importNext(int sourceId) async {
    calls++;
    await pending?.future;
    if (fail) throw const TelegramException(TelegramFailure.connection);
    if (paused) throw const TelegramException(TelegramFailure.invalidInput);
    if (records.isEmpty) records.addAll(designMedia);
    complete = true;
    revision++;
  }

  @override
  Future<bool> updateNext(int sourceId) async {
    await importNext(sourceId);
    return true;
  }

  @override
  Future<void> pauseImport(int sourceId, bool value) async {
    if (value) {
      pauseCalls++;
      await pendingPause?.future;
    }
    paused = value;
    revision++;
  }

  @override
  Future<String> messageLink(LocalMedia media) async {
    if (!linkSupported) {
      throw const TelegramException(TelegramFailure.linkUnsupported);
    }
    if (fail) throw const TelegramException(TelegramFailure.unavailable);
    return 'https://t.me/c/123456/${media.messageId}';
  }
}
