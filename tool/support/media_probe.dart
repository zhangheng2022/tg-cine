import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'media_selection.dart';
import 'tdlib_probe.dart';
import 'playback_trace.dart';

/// Bounded development reads; TDLib caches bytes in the private session folder.
class MediaProbe {
  MediaProbe._(
    this.request,
    this.fileId,
    this.size,
    this.duration,
    this.mimeType,
    this.trace,
  );

  final Future<Map<String, dynamic>> Function(Map<String, dynamic>) request;
  final int fileId;
  final int size;
  final int? duration;
  final String mimeType;
  final PlaybackTrace? trace;
  static const chunkSize = 512 * 1024;
  static const prefetchSize = 2 * 1024 * 1024;
  int? _downloadStart;
  int _downloadEnd = 0;
  bool _closed = false;
  int _readGeneration = 0;
  final _cache = <(int, Uint8List)>[];

  static Future<MediaProbe> open(
    Map<String, dynamic> selection,
    Future<Map<String, dynamic>> Function(Map<String, dynamic>) request, {
    PlaybackTrace? trace,
  }) async {
    final chatId = selection['chatId'];
    final messageId = selection['messageId'];
    if (chatId is! int || chatId == 0 || messageId is! int || messageId <= 0) {
      throw const FormatException('Invalid local media selection');
    }
    // Chat databases are disabled in this harness, so restore the chosen source.
    var limit = 0;
    var found = false;
    final exhausted = <String>{};
    while (!found && exhausted.length < 2) {
      limit += 100;
      for (final list in ['chatListMain', 'chatListArchive']) {
        if (!exhausted.contains(list)) {
          try {
            await request({
              '@type': 'loadChats',
              'chat_list': {'@type': list},
              'limit': 100,
            });
          } on TdlibRequestError catch (error) {
            if (error.code != 404) rethrow;
            exhausted.add(list);
          }
        }
        final chats = await request({
          '@type': 'getChats',
          'chat_list': {'@type': list},
          'limit': limit,
        });
        if ((chats['chat_ids'] as List).contains(chatId)) {
          found = true;
          break;
        }
      }
    }
    if (!found) throw StateError('Selected source unavailable');
    final message = await request({
      '@type': 'getMessage',
      'chat_id': chatId,
      'message_id': messageId,
    });
    final file = videoFile(message);
    if (file == null ||
        file['id'] is! int ||
        file['id'] <= 0 ||
        file['size'] is! int ||
        file['size'] <= 0) {
      throw StateError('Selected video unavailable or size unknown');
    }
    final remoteId = (file['remote'] as Map?)?['id'] as String? ?? '';
    if (remoteId.startsWith('http://') || remoteId.startsWith('https://')) {
      throw UnsupportedError(
        'External file generation is not supported by this probe',
      );
    }
    final content = message['content'] as Map<String, dynamic>;
    final media = (content['video'] ?? content['document']) as Map;
    final mime = media['mime_type'] as String? ?? '';
    return MediaProbe._(
      request,
      file['id'] as int,
      file['size'] as int,
      media['duration'] as int?,
      RegExp(r'^video/[a-zA-Z0-9.+-]+$').hasMatch(mime)
          ? mime
          : 'application/octet-stream',
      trace,
    );
  }

  void _checkRange(int offset, int count) {
    if (offset < 0 ||
        count <= 0 ||
        count > chunkSize ||
        offset + count > size) {
      throw const FormatException('Invalid bounded media range');
    }
    if (_closed) throw StateError('Media reader closed');
  }

  Uint8List? _cached(int offset, int count) {
    for (var index = _cache.length - 1; index >= 0; index--) {
      final cached = _cache[index];
      if (offset >= cached.$1 &&
          offset + count <= cached.$1 + cached.$2.length) {
        _cache.removeAt(index);
        _cache.add(cached);
        trace?.record(PlaybackStage.cacheHit, offset: offset, bytes: count);
        return Uint8List.fromList(
          Uint8List.sublistView(
            cached.$2,
            offset - cached.$1,
            offset - cached.$1 + count,
          ),
        );
      }
    }
    return null;
  }

  /// Reads available bytes without replacing or cancelling the cold download window.
  Future<Uint8List?> readReady(int offset, int count) async {
    _checkRange(offset, count);
    final cached = _cached(offset, count);
    if (cached != null) return cached;
    final prefix = await _prefix(offset);
    if (_closed) throw StateError('Media reader closed');
    if (prefix < count) return null;
    return _readAvailable(offset, count, prefix);
  }

  Future<Uint8List> _readAvailable(
    int offset,
    int count,
    int prefix, {
    int? generation,
  }) async {
    final readCount = min(chunkSize, min(prefix, size - offset));
    final reading = Stopwatch()..start();
    final response = await request({
      '@type': 'readFilePart',
      'file_id': fileId,
      'offset': offset,
      'count': readCount,
    });
    final bytes = base64Decode(response['data'] as String);
    if (_closed || (generation != null && generation != _readGeneration)) {
      throw StateError('Media read closed or superseded');
    }
    if (bytes.length != readCount) throw StateError('Incomplete media range');
    trace?.record(
      PlaybackStage.nativeRead,
      offset: offset,
      bytes: bytes.length,
      durationUs: reading.elapsedMicroseconds,
    );
    _cache.add((offset, bytes));
    if (_cache.length > 8) _cache.removeAt(0);
    return Uint8List.fromList(Uint8List.sublistView(bytes, 0, count));
  }

  Future<Uint8List> read(int offset, int count) async {
    _checkRange(offset, count);
    final cached = _cached(offset, count);
    if (cached != null) return cached;
    final generation = _readGeneration;
    final timer = Stopwatch()..start();
    var polls = 0;
    try {
      var prefix = await _prefix(offset);
      var requiredPrefix = count;
      if (generation != _readGeneration) {
        throw StateError('Media read superseded');
      }
      if (prefix < count &&
          (_downloadStart == null ||
              offset < _downloadStart! ||
              offset + count > _downloadEnd)) {
        await _cancelDownload();
        if (_closed || generation != _readGeneration) {
          throw StateError('Media read closed or superseded');
        }
        // Native file parts are aligned; a relative window can end short.
        _downloadStart = offset ~/ chunkSize * chunkSize;
        _downloadEnd = min(size, _downloadStart! + prefetchSize);
        await request({
          '@type': 'downloadFile',
          'file_id': fileId,
          'priority': 32,
          'offset': _downloadStart,
          'limit': _downloadEnd - _downloadStart!,
          'synchronous': false,
        });
        trace?.record(
          PlaybackStage.windowStart,
          offset: _downloadStart,
          bytes: _downloadEnd - _downloadStart!,
        );
        prefix = await _prefix(offset);
        // Finish this bounded prefetch before another track can replace its download window.
        requiredPrefix = _downloadEnd - offset;
      }
      while (true) {
        if (generation != _readGeneration) {
          throw StateError('Media read superseded');
        }
        if (prefix >= requiredPrefix) break;
        if (timer.elapsed >= const Duration(minutes: 2)) {
          throw TimeoutException('Media range download timed out');
        }
        if (++polls % 20 == 0) {
          await request({'@type': 'getFile', 'file_id': fileId});
        }
        await Future<void>.delayed(const Duration(milliseconds: 100));
        prefix = await _prefix(offset);
      }
      trace?.record(
        PlaybackStage.prefixWait,
        durationUs: timer.elapsedMicroseconds,
        offset: offset,
      );
      if (requiredPrefix != count) {
        trace?.record(
          PlaybackStage.windowComplete,
          offset: offset,
          bytes: requiredPrefix,
        );
      }
      return await _readAvailable(
        offset,
        count,
        prefix,
        generation: generation,
      );
    } catch (_) {
      await _cancelDownload();
      rethrow;
    }
  }

  Future<int> _prefix(int offset) async {
    final response = await request({
      '@type': 'getFileDownloadedPrefixSize',
      'file_id': fileId,
      'offset': offset,
    });
    final size = response['size'];
    if (size is! int || size < 0) {
      throw StateError('Invalid downloaded prefix');
    }
    return size;
  }

  Future<void> _cancelDownload() async {
    if (_downloadStart != null) {
      trace?.record(PlaybackStage.windowCancel, offset: _downloadStart);
      _downloadStart = null;
      _downloadEnd = 0;
      await request({
        '@type': 'cancelDownloadFile',
        'file_id': fileId,
        'only_if_pending': false,
      });
    }
  }

  Future<void> close() async {
    _closed = true;
    _readGeneration++;
    _cache.clear();
    await _cancelDownload();
  }

  /// Supersedes a read; its own cleanup keeps native RPCs sequential.
  void cancelPendingRead() => _readGeneration++;

  /// Warm the startup bytes and a bounded MP4 index without rewriting media.
  Future<Map<String, dynamic>> preparePlayback() async {
    final timer = Stopwatch()..start();
    for (var offset = 0; offset < min(size, 2 * chunkSize);) {
      final count = min(chunkSize, min(size, 2 * chunkSize) - offset);
      await read(offset, count);
      offset += count;
    }
    var status = 'head-prepared';
    var indexBytes = 0;
    if (mimeType == 'video/mp4') {
      var offset = 0;
      for (var boxes = 0; boxes < 8 && offset + 16 <= size; boxes++) {
        final header = await read(offset, 16);
        final data = ByteData.sublistView(header);
        final type = String.fromCharCodes(header.sublist(4, 8));
        if (offset == 0 && type != 'ftyp') break;
        final shortSize = data.getUint32(0);
        final boxSize = shortSize == 1
            ? data.getUint64(8)
            : shortSize == 0
            ? size - offset
            : shortSize;
        final headerSize = shortSize == 1 ? 16 : 8;
        if (boxSize < headerSize || boxSize > size - offset) break;
        if (type == 'moov') {
          if (boxSize > 4 * 1024 * 1024) {
            status = 'index-too-large';
            break;
          }
          for (var position = offset; position < offset + boxSize;) {
            final count = min(chunkSize, offset + boxSize - position);
            await read(position, count);
            position += count;
          }
          indexBytes = boxSize;
          status = 'mp4-index-prepared';
          break;
        }
        offset += boxSize;
      }
    }
    return {
      'status': status,
      'indexBytes': indexBytes,
      'elapsedMs': timer.elapsedMilliseconds,
    };
  }

  Future<Map<String, dynamic>> verify() async {
    final ranges = <Map<String, int>>[];
    Uint8List? first;
    for (final offset in {
      0,
      (size ~/ 2 ~/ chunkSize) * chunkSize,
      ((size - 1) ~/ chunkSize) * chunkSize,
    }) {
      final timer = Stopwatch()..start();
      final bytes = await read(offset, min(chunkSize, size - offset));
      first ??= bytes;
      ranges.add({
        'offset': offset,
        'bytes': bytes.length,
        'elapsedMs': timer.elapsedMilliseconds,
      });
    }
    final repeated = await read(0, first!.length);
    for (var index = 0; index < first.length; index++) {
      if (first[index] != repeated[index]) {
        throw StateError('Media reread mismatch');
      }
    }
    return {
      'checkedAt': DateTime.now().toUtc().toIso8601String(),
      'status': 'media-ranges-verified',
      'size': size,
      'durationSeconds': duration,
      'mimeType': mimeType,
      'ranges': ranges,
      'rereadMatched': true,
      'decodedPlaybackVerified': false,
    };
  }
}
