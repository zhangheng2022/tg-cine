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
  }) async {
    if (fail) throw const TelegramException(TelegramFailure.storage);
    return records
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
