import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/support/media_probe.dart';
import '../../tool/support/tdlib_probe.dart';

Future<MediaProbe> probe(
  List<Map<String, dynamic>> calls, {
  int prefix = MediaProbe.prefetchSize,
  bool shortRead = false,
  Object? prefixError,
  String remoteId = 'opaque-test-file-id',
  int fileId = 9,
  int fileSize = 2 * MediaProbe.chunkSize + 7,
  Uint8List? fileBytes,
  bool alignedWindows = false,
  bool gradualPrefetch = false,
}) {
  final windows = <(int, int)>[];
  final polls = <int, int>{};
  return MediaProbe.open({'chatId': -42, 'messageId': 7}, (request) async {
    calls.add(request);
    switch (request['@type']) {
      case 'loadChats':
        throw const TdlibRequestError(404);
      case 'getChats':
        return {
          'chat_ids': [-42],
        };
      case 'getMessage':
        return {
          'content': {
            '@type': 'messageVideo',
            'is_secret': false,
            'video': {
              'duration': 123,
              'mime_type': 'video/mp4',
              'video': {
                'id': fileId,
                'size': fileBytes?.length ?? fileSize,
                'remote': {'id': remoteId},
              },
            },
          },
        };
      case 'downloadFile':
        final requestedOffset = request['offset'] as int;
        final offset = alignedWindows
            ? requestedOffset ~/ MediaProbe.chunkSize * MediaProbe.chunkSize
            : requestedOffset;
        windows.add((offset, offset + (request['limit'] as int)));
        return {'@type': 'file'};
      case 'getFile':
        return {'@type': 'file'};
      case 'getFileDownloadedPrefixSize':
        final offset = request['offset'] as int;
        if (prefix < 0) return {'size': prefix};
        for (final window in windows.reversed) {
          if (offset >= window.$1 && offset < window.$2) {
            if (prefixError != null) throw prefixError;
            polls[offset] = (polls[offset] ?? 0) + 1;
            if (alignedWindows && polls[offset]! > 5) {
              throw StateError('Incomplete window was not restarted');
            }
            return {
              'size': gradualPrefetch && polls[offset] == 1
                  ? min(MediaProbe.chunkSize, window.$2 - offset)
                  : prefix == 0 && polls[offset] == 1
                  ? 0
                  : min(
                      prefix == 0 ? MediaProbe.prefetchSize : prefix,
                      window.$2 - offset,
                    ),
            };
          }
        }
        return {'size': 0};
      case 'cancelDownloadFile':
        return {'@type': 'ok'};
      case 'readFilePart':
        final count = request['count'] as int;
        final offset = request['offset'] as int;
        return {
          'data': base64Encode(
            fileBytes == null
                ? Uint8List(shortRead ? count - 1 : count)
                : Uint8List.sublistView(fileBytes, offset, offset + count),
          ),
        };
      default:
        fail('Unexpected request');
    }
  });
}

Uint8List mp4({int indexSize = 1024, bool extended = false}) {
  final mediaSize = MediaProbe.prefetchSize + (extended ? 16 : 8);
  final indexOffset = 24 + mediaSize;
  final bytes = Uint8List(indexOffset + indexSize);
  final data = ByteData.sublistView(bytes);
  data.setUint32(0, 24);
  bytes.setRange(4, 8, ascii.encode('ftyp'));
  data.setUint32(24, extended ? 1 : mediaSize);
  bytes.setRange(28, 32, ascii.encode('mdat'));
  if (extended) data.setUint64(32, mediaSize);
  data.setUint32(indexOffset, indexSize);
  bytes.setRange(indexOffset + 4, indexOffset + 8, ascii.encode('moov'));
  return bytes;
}

void main() {
  test(
    'failed range update cancels native work and a later read can restart',
    () async {
      final calls = <Map<String, dynamic>>[];
      final base = await probe(calls, fileSize: 3 * MediaProbe.prefetchSize);
      var downloads = 0;
      final media = await MediaProbe.open({'chatId': -42, 'messageId': 7}, (
        request,
      ) async {
        if (request['@type'] == 'downloadFile' && ++downloads == 2) {
          throw const TdlibRequestError(500);
        }
        return base.request(request);
      });
      await media.read(0, 20);
      final next = MediaProbe.prefetchSize + MediaProbe.chunkSize;
      await expectLater(
        media.read(next, 20),
        throwsA(isA<TdlibRequestError>()),
      );
      expect(
        calls.where((call) => call['@type'] == 'cancelDownloadFile'),
        hasLength(1),
      );
      expect(await media.read(next, 20), hasLength(20));
      expect(downloads, 3);
      expect(
        calls
            .where((call) => call['@type'] == 'downloadFile')
            .every(
              (call) =>
                  (call['limit'] as int) > 0 &&
                  (call['limit'] as int) <= MediaProbe.prefetchSize,
            ),
        isTrue,
      );
      await media.close();
      expect(
        calls.where((call) => call['@type'] == 'cancelDownloadFile'),
        hasLength(2),
      );
      await base.close();
    },
  );

  test(
    'closing during prefetch wait cannot start a replacement download',
    () async {
      final calls = <Map<String, dynamic>>[];
      final base = await probe(calls, fileSize: 2 * MediaProbe.prefetchSize);
      final waiting = Completer<void>();
      final release = Completer<void>();
      var switching = false;
      final media = await MediaProbe.open({'chatId': -42, 'messageId': 7}, (
        request,
      ) async {
        if (switching &&
            request['@type'] == 'getFileDownloadedPrefixSize' &&
            request['offset'] == 0) {
          waiting.complete();
          await release.future;
        }
        return base.request(request);
      });
      await media.read(0, 20);
      switching = true;
      final pending = media.read(
        MediaProbe.prefetchSize + MediaProbe.chunkSize,
        20,
      );
      final failure = expectLater(pending, throwsStateError);
      await waiting.future;
      await media.close();
      release.complete();
      await failure;
      expect(
        calls.where((call) => call['@type'] == 'downloadFile'),
        hasLength(1),
      );
      expect(calls.last['@type'], 'getFileDownloadedPrefixSize');
      expect(
        calls.where((call) => call['@type'] == 'cancelDownloadFile'),
        hasLength(1),
      );
      await base.close();
    },
  );
  test('ready reads never start or cancel a download and retain bounded cache copies', () async {
    final calls = <Map<String, dynamic>>[];
    final media = await probe(
      calls,
      fileSize: MediaProbe.prefetchSize + 2 * MediaProbe.chunkSize,
    );
    expect(await media.readReady(0, 20), isNull);
    expect(calls.any((call) => call['@type'] == 'downloadFile'), isFalse);
    await media.read(0, 20);
    calls.clear();
    final ready = await media.readReady(MediaProbe.chunkSize, 20);
    expect(ready, hasLength(20));
    expect(calls.map((call) => call['@type']), [
      'getFileDownloadedPrefixSize',
      'readFilePart',
    ]);
    ready![0] = 99;
    calls.clear();
    expect((await media.readReady(MediaProbe.chunkSize, 1))!.single, 0);
    expect(calls, isEmpty);
    await expectLater(media.readReady(-1, 1), throwsFormatException);
    await media.close();
    calls.clear();
    await expectLater(media.readReady(0, 1), throwsStateError);
    expect(calls, isEmpty);
  });
  test(
    'ready reads reject short native parts without cancelling another lane',
    () async {
      final calls = <Map<String, dynamic>>[];
      final base = await probe(
        calls,
        fileSize: MediaProbe.prefetchSize + 2 * MediaProbe.chunkSize,
      );
      final media = await MediaProbe.open({'chatId': -42, 'messageId': 7}, (
        request,
      ) async {
        if (request['@type'] == 'getFileDownloadedPrefixSize') {
          return {'size': MediaProbe.chunkSize};
        }
        if (request['@type'] == 'readFilePart') {
          return {
            'data': base64Encode([0]),
          };
        }
        return base.request(request);
      });
      calls.clear();
      await expectLater(media.readReady(0, 20), throwsStateError);
      expect(
        calls.any((call) => call['@type'] == 'cancelDownloadFile'),
        isFalse,
      );
      await media.close();
      await base.close();
    },
  );
  test(
    'returns the first readable chunk without waiting for the whole prefetch',
    () async {
      final calls = <Map<String, dynamic>>[];
      final media = await probe(
        calls,
        fileSize: MediaProbe.prefetchSize + 2 * MediaProbe.chunkSize,
        gradualPrefetch: true,
      );
      expect(await media.read(0, 64 * 1024), hasLength(64 * 1024));
      final download = calls.singleWhere(
        (call) => call['@type'] == 'downloadFile',
      );
      expect(download['limit'], MediaProbe.prefetchSize);
      final reading = calls.indexWhere(
        (call) => call['@type'] == 'readFilePart',
      );
      expect(
        calls
            .sublist(calls.indexOf(download) + 1, reading)
            .where((call) => call['@type'] == 'getFileDownloadedPrefixSize'),
        hasLength(1),
      );
      expect(calls[reading]['count'], MediaProbe.chunkSize);
      await media.close();
    },
  );
  test(
    'switching cold tracks waits for prefetch while cached reads continue',
    () async {
      final calls = <Map<String, dynamic>>[];
      final base = await probe(calls, fileSize: 2 * MediaProbe.prefetchSize);
      var complete = false;
      var waiting = false;
      final media = await MediaProbe.open({'chatId': -42, 'messageId': 7}, (
        request,
      ) async {
        if (request['@type'] == 'getFileDownloadedPrefixSize' &&
            request['offset'] == 0 &&
            calls.any((call) => call['@type'] == 'downloadFile')) {
          waiting = true;
          return {
            'size': complete ? MediaProbe.prefetchSize : MediaProbe.chunkSize,
          };
        }
        return base.request(request);
      });
      expect(await media.read(0, 64 * 1024), hasLength(64 * 1024));
      waiting = false;
      final next = media.read(
        MediaProbe.prefetchSize + MediaProbe.chunkSize,
        64 * 1024,
      );
      while (!waiting) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(
        calls.where((call) => call['@type'] == 'downloadFile'),
        hasLength(1),
      );
      expect(
        calls.any((call) => call['@type'] == 'cancelDownloadFile'),
        isFalse,
      );
      expect(await media.readReady(64 * 1024, 64 * 1024), hasLength(64 * 1024));
      complete = true;
      expect(await next, hasLength(64 * 1024));
      expect(
        calls.where((call) => call['@type'] == 'downloadFile'),
        hasLength(2),
      );
      await media.close();
      await base.close();
    },
  );
  test('unaligned reads restart at the native window boundary instead of waiting for a missing tail', () async {
    final calls = <Map<String, dynamic>>[];
    final media = await probe(
      calls,
      fileSize: MediaProbe.prefetchSize + 2 * MediaProbe.chunkSize,
      alignedWindows: true,
    );
    await media.read(100, 20);
    expect(
      await media.read(MediaProbe.prefetchSize - 64 * 1024 + 100, 64 * 1024),
      hasLength(64 * 1024),
    );
    final downloads = calls
        .where((call) => call['@type'] == 'downloadFile')
        .toList();
    expect(downloads, hasLength(2));
    expect(downloads.map((call) => call['offset']), [
      0,
      MediaProbe.prefetchSize - MediaProbe.chunkSize,
    ]);
    expect(
      downloads.every(
        (call) => (call['limit'] as int) <= MediaProbe.prefetchSize,
      ),
      true,
    );
    await media.close();
  });
  test('nearby demux ranges reuse readable memory bytes without native RPCs or caller mutation', () async {
    final calls = <Map<String, dynamic>>[];
    final media = await probe(calls);
    final first = await media.read(0, 64 * 1024);
    expect(calls.last['count'], MediaProbe.chunkSize);
    first[0] = 99;
    final count = calls.length;
    expect(await media.read(1024, 64 * 1024), hasLength(64 * 1024));
    expect((await media.read(0, 1)).single, 0);
    expect(calls.length, count);
    await media.close();
    await expectLater(media.read(0, 1), throwsStateError);
  });

  test('memory cache evicts beyond eight bounded native chunks', () async {
    final calls = <Map<String, dynamic>>[];
    final media = await probe(calls, fileSize: 10 * MediaProbe.chunkSize);
    for (var index = 0; index < 9; index++) {
      await media.read(index * MediaProbe.chunkSize, 64 * 1024);
    }
    expect(
      calls.where((call) => call['@type'] == 'readFilePart'),
      hasLength(9),
    );
    await media.read(0, 64 * 1024);
    expect(
      calls.where((call) => call['@type'] == 'readFilePart'),
      hasLength(10),
    );
    await media.close();
  });
  test(
    'fails before downloading invalid files and external generation URLs',
    () async {
      for (final id in [0, -1]) {
        final calls = <Map<String, dynamic>>[];
        await expectLater(probe(calls, fileId: id), throwsStateError);
        expect(calls.any((call) => call['@type'] == 'downloadFile'), isFalse);
      }
      for (final url in [
        'https://example.test/video',
        'http://example.test/video',
      ]) {
        final calls = <Map<String, dynamic>>[];
        await expectLater(probe(calls, remoteId: url), throwsUnsupportedError);
        expect(calls.any((call) => call['@type'] == 'downloadFile'), isFalse);
      }
    },
  );

  test(
    'does not fetch another message if the saved source is unavailable',
    () async {
      await expectLater(
        MediaProbe.open({'chatId': -42, 'messageId': 7}, (request) async {
          if (request['@type'] == 'loadChats') {
            throw const TdlibRequestError(404);
          }
          expect(request['@type'], 'getChats');
          return {'chat_ids': <int>[]};
        }),
        throwsStateError,
      );
    },
  );
  test('restores only the selected source and verifies bounded head/middle/tail and reread', () async {
    final calls = <Map<String, dynamic>>[];
    final media = await probe(calls);
    final report = await media.verify();
    expect(report['status'], 'media-ranges-verified');
    expect(report['rereadMatched'], isTrue);
    expect(report['decodedPlaybackVerified'], isFalse);
    expect(report.containsKey('chatId'), isFalse);
    expect(
      calls.singleWhere((call) => call['@type'] == 'getMessage')['chat_id'],
      -42,
    );
    final downloads = calls
        .where((call) => call['@type'] == 'downloadFile')
        .toList();
    expect(downloads.map((call) => call['offset']), [0]);
    expect(downloads.map((call) => call['limit']), [media.size]);
    expect(downloads.every((call) => call['synchronous'] == false), isTrue);
    await media.close();
    expect(calls.last['@type'], 'cancelDownloadFile');
  });

  test('waits for readable prefix before reading sparse files; rejects short reads', () async {
    final calls = <Map<String, dynamic>>[];
    final incomplete = await probe(calls, prefix: 0);
    await incomplete.read(100, 20);
    final prefixCalls = calls
        .where((call) => call['@type'] == 'getFileDownloadedPrefixSize')
        .toList();
    expect(prefixCalls, hasLength(3));
    expect(
      calls.indexWhere((call) => call['@type'] == 'readFilePart'),
      greaterThan(calls.indexOf(prefixCalls.last)),
    );
    expect(calls.any((call) => call['@type'] == 'cancelDownloadFile'), isFalse);
    await incomplete.close();
    expect(calls.last['@type'], 'cancelDownloadFile');
    final short = await probe([], shortRead: true);
    await expectLater(short.read(100, 20), throwsStateError);
  });

  test(
    'cancels the download after a native prefix timeout without reading bytes',
    () async {
      final calls = <Map<String, dynamic>>[];
      final media = await probe(
        calls,
        prefixError: TimeoutException('Native prefix request timed out'),
      );
      await expectLater(media.read(100, 20), throwsA(isA<TimeoutException>()));
      expect(calls.where((call) => call['@type'] == 'readFilePart'), isEmpty);
      expect(calls.last['@type'], 'cancelDownloadFile');
      expect(calls.last['only_if_pending'], isFalse);
    },
  );

  test(
    'rejects invalid selection and ranges before requesting bytes',
    () async {
      await expectLater(
        MediaProbe.open({
          'chatId': 0,
          'messageId': 7,
        }, (_) async => fail('No request expected')),
        throwsFormatException,
      );
      final calls = <Map<String, dynamic>>[];
      final media = await probe(calls);
      calls.clear();
      for (final range in [
        (-1, 1),
        (0, 0),
        (0, MediaProbe.chunkSize + 1),
        (media.size, 1),
      ]) {
        await expectLater(
          media.read(range.$1, range.$2),
          throwsFormatException,
        );
      }
      expect(calls, isEmpty);
    },
  );

  test('adjacent reads reuse a bounded window; range updates preserve the task and cached reads do not restart', () async {
    final calls = <Map<String, dynamic>>[];
    final media = await probe(
      calls,
      prefix: 0,
      fileSize: MediaProbe.prefetchSize + 2 * MediaProbe.chunkSize + 7,
    );
    await media.read(0, MediaProbe.chunkSize);
    await media.read(MediaProbe.chunkSize, MediaProbe.chunkSize);
    expect(
      calls.where((call) => call['@type'] == 'downloadFile'),
      hasLength(1),
    );
    expect(calls.any((call) => call['@type'] == 'cancelDownloadFile'), isFalse);
    await media.read(MediaProbe.prefetchSize + MediaProbe.chunkSize, 20);
    final downloads = calls
        .where((call) => call['@type'] == 'downloadFile')
        .toList();
    expect(downloads, hasLength(2));
    expect(downloads.first['limit'], MediaProbe.prefetchSize);
    expect(
      downloads.last['limit'],
      media.size - MediaProbe.prefetchSize - MediaProbe.chunkSize,
    );
    expect(calls.any((call) => call['@type'] == 'cancelDownloadFile'), isFalse);
    await media.read(0, 20);
    expect(
      calls.where((call) => call['@type'] == 'downloadFile'),
      hasLength(2),
    );
    await media.close();
    final count = calls.length;
    await media.close();
    expect(calls, hasLength(count));
    await expectLater(media.read(0, 1), throwsStateError);
  });

  test(
    'rejects a negative downloaded prefix before reading sparse bytes',
    () async {
      final calls = <Map<String, dynamic>>[];
      final media = await probe(calls, prefix: -1);
      await expectLater(media.read(0, 16), throwsStateError);
      expect(calls.any((call) => call['@type'] == 'readFilePart'), isFalse);
    },
  );

  test(
    'warms bounded head and tail MP4 index, including extended box sizes',
    () async {
      for (final extended in [false, true]) {
        final calls = <Map<String, dynamic>>[];
        final media = await probe(calls, fileBytes: mp4(extended: extended));
        final report = await media.preparePlayback();
        expect(report['status'], 'mp4-index-prepared');
        expect(report['indexBytes'], 1024);
        expect(
          calls
              .where((call) => call['@type'] == 'downloadFile')
              .every(
                (call) => (call['limit'] as int) <= MediaProbe.prefetchSize,
              ),
          isTrue,
        );
        expect(
          calls
              .where((call) => call['@type'] == 'readFilePart')
              .every((call) => (call['count'] as int) <= MediaProbe.chunkSize),
          isTrue,
        );
        await media.close();
      }
    },
  );

  test('superseding a waiting read cancels it before reading bytes and allows the next range', () async {
    final calls = <Map<String, dynamic>>[];
    final media = await probe(calls, prefix: 0);
    final pending = media.read(0, 20);
    while (!calls.any((call) => call['@type'] == 'downloadFile')) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
    media.cancelPendingRead();
    await expectLater(pending, throwsStateError);
    expect(calls.any((call) => call['@type'] == 'readFilePart'), isFalse);
    expect(calls.last['@type'], 'cancelDownloadFile');
    expect(await media.read(100, 20), hasLength(20));
    await media.close();
  });

  test(
    'large or malformed indexes fall back without trusting box lengths',
    () async {
      final oversized = await probe(
        [],
        fileBytes: mp4(indexSize: 4 * 1024 * 1024 + 1),
      );
      expect((await oversized.preparePlayback())['status'], 'index-too-large');
      await oversized.close();
      final bytes = mp4();
      ByteData.sublistView(bytes).setUint32(24, bytes.length + 1);
      final calls = <Map<String, dynamic>>[];
      final malformed = await probe(calls, fileBytes: bytes);
      expect((await malformed.preparePlayback())['status'], 'head-prepared');
      expect(
        calls
            .where((call) => call['@type'] == 'readFilePart')
            .every((call) => (call['offset'] as int) < bytes.length),
        isTrue,
      );
      await malformed.close();
    },
  );
}
