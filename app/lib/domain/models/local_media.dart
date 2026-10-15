import 'dart:convert';

/// An actual Telegram file version; filenames are display metadata, never identity.
class LocalMedia {
  const LocalMedia({
    required this.sourceId,
    required this.messageId,
    required this.remoteUniqueId,
    required this.sizeBytes,
    required this.fileName,
    this.durationSeconds = 0,
    this.caption = '',
    this.sentAt = 0,
  });

  final int sourceId;
  final int messageId;
  final String remoteUniqueId;
  final int sizeBytes;
  final String fileName;
  final int durationSeconds;
  final String caption;
  final int sentAt;

  String get versionKey =>
      jsonEncode([sourceId, messageId, remoteUniqueId, sizeBytes]);
}

class ImportCheckpoint {
  const ImportCheckpoint({
    this.nextMessageId = 0,
    this.paused = false,
    this.complete = false,
    this.revision = 0,
  });

  final int nextMessageId;
  final bool paused;
  final bool complete;
  final int revision;
}

class SourceImport {
  const SourceImport({
    required this.sourceId,
    required this.title,
    required this.imported,
    required this.checkpoint,
  });
  final int sourceId;
  final String title;
  final int imported;
  final ImportCheckpoint checkpoint;
}

class TelegramMediaPage {
  TelegramMediaPage({
    required List<LocalMedia> media,
    required this.nextMessageId,
  }) : media = List.unmodifiable(media);
  final List<LocalMedia> media;
  final int nextMessageId;
}

class LocalMediaException implements Exception {
  const LocalMediaException(this.failure);
  final LocalMediaFailure failure;

  @override
  String toString() => 'LocalMediaException(${failure.name})';
}

enum LocalMediaFailure { invalidInput, storage, conflict }
