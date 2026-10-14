import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/support/local_media_server.dart';

void main() {
  late HttpClient client;
  setUp(() => client = HttpClient());
  tearDown(() => client.close(force: true));

  test('available audio bypasses a blocked cold video read without cancellation or budget overflow', () async {
    final started = Completer<void>();
    final cold = Completer<Uint8List>();
    var cancellations = 0;
    final server = await LocalMediaServer.start(
      size: 2,
      mimeType: 'video/mp4',
      separateStreams: true,
      maxBytes: 2,
      readReady: (offset, count) async =>
          offset == 1 ? Uint8List.fromList([8]) : null,
      read: (_, _) {
        started.complete();
        return cold.future;
      },
      cancelRead: () => cancellations++,
    );
    addTearDown(server.close);
    Future<List<int>> fetchBytes(Uri uri, String range) async {
      final request = await client.getUrl(uri);
      request.headers.set(HttpHeaders.rangeHeader, range);
      return (await request.close()).expand((chunk) => chunk).toList();
    }

    final video = fetchBytes(server.uri, 'bytes=0-0');
    await started.future;
    final audio = server.uri.replace(path: '${server.uri.path}/audio');
    expect(
      await fetchBytes(audio, 'bytes=1-1').timeout(const Duration(seconds: 1)),
      [8],
    );
    expect(cold.isCompleted, isFalse);
    expect(cancellations, 0);
    cold.complete(Uint8List.fromList([7]));
    expect(await video, [7]);
    expect(server.bytesServed, 2);
    expect(server.failedRequests, 0);
  });

  test(
    'closing during an available read discards bytes and releases its budget',
    () async {
      final started = Completer<void>();
      final ready = Completer<Uint8List?>();
      final server = await LocalMediaServer.start(
        size: 1,
        mimeType: 'video/mp4',
        readReady: (_, _) {
          started.complete();
          return ready.future;
        },
        read: (_, _) => throw StateError('No cold read expected'),
      );
      final request = await client.getUrl(server.uri);
      final response = request.close().then((value) => value.drain<void>());
      final failure = expectLater(response, throwsA(anything));
      await started.future;
      final closing = server.close();
      ready.complete(Uint8List.fromList([9]));
      await closing;
      await failure;
      expect(server.bytesServed, 0);
      expect(server.pendingRequests, 0);
    },
  );

  test(
    'enforces an explicit bounded session budget and validates its upper limit',
    () async {
      final server = await LocalMediaServer.start(
        size: 10,
        mimeType: 'video/mp4',
        maxBytes: 5,
        maxRanges: 1,
        read: (_, count) async => Uint8List(count),
      );
      addTearDown(server.close);
      final first = await client.getUrl(server.uri);
      first.headers.set(HttpHeaders.rangeHeader, 'bytes=0-4');
      expect(
        await (await first.close()).fold<int>(
          0,
          (sum, bytes) => sum + bytes.length,
        ),
        5,
      );
      final second = await client.getUrl(server.uri);
      second.headers.set(HttpHeaders.rangeHeader, 'bytes=5-9');
      final response = await second.close();
      expect(response.statusCode, 503);
      await response.drain<void>();
      expect(server.bytesServed, 5);
      expect(server.ranges.length, 1);
      for (final limit in [0, -1, 128 * 1024 * 1024 + 1]) {
        await expectLater(
          LocalMediaServer.start(
            size: 10,
            mimeType: 'video/mp4',
            maxBytes: limit,
            read: (_, count) async => Uint8List(count),
          ),
          throwsFormatException,
        );
      }
      for (final limit in [0, -1, 513]) {
        await expectLater(
          LocalMediaServer.start(
            size: 10,
            mimeType: 'video/mp4',
            maxRanges: limit,
            read: (_, count) async => Uint8List(count),
          ),
          throwsFormatException,
        );
      }
    },
  );

  test(
    'exhausting the range budget rejects reads even with bytes remaining',
    () async {
      final server = await LocalMediaServer.start(
        size: 10,
        mimeType: 'video/mp4',
        maxRanges: 1,
        read: (_, count) async => Uint8List(count),
      );
      addTearDown(server.close);
      final first = await client.getUrl(server.uri);
      first.headers.set(HttpHeaders.rangeHeader, 'bytes=0-0');
      await (await first.close()).drain<void>();
      final next = await client.getUrl(server.uri);
      next.headers.set(HttpHeaders.rangeHeader, 'bytes=1-1');
      final response = await next.close();
      expect(response.statusCode, 503);
      await response.drain<void>();
      expect(server.bytesServed, 1);
      expect(server.ranges.length, 1);
    },
  );

  Future<HttpClientResponse> fetch(
    Uri uri, {
    String method = 'GET',
    String? range,
    String? host,
  }) async {
    final request = await client.openUrl(method, uri);
    if (range != null) request.headers.set(HttpHeaders.rangeHeader, range);
    if (host != null) request.headers.set(HttpHeaders.hostHeader, host);
    return request.close();
  }

  test(
    'serves exact single ranges and HEAD without exposing sparse bytes',
    () async {
      final calls = <(int, int)>[];
      final server = await LocalMediaServer.start(
        size: 100,
        mimeType: 'video/mp4',
        read: (offset, count) async {
          calls.add((offset, count));
          return Uint8List.fromList(List.generate(count, (i) => offset + i));
        },
      );
      addTearDown(server.close);
      final head = await fetch(server.uri, method: 'HEAD');
      expect(head.contentLength, 100);
      await head.drain<void>();
      expect(calls, isEmpty);
      for (final entry in [
        ('bytes=10-19', 10, 19),
        ('bytes=-4', 96, 99),
        ('bytes=98-', 98, 99),
        ('bytes=98-200', 98, 99),
      ]) {
        final response = await fetch(server.uri, range: entry.$1);
        expect(response.statusCode, 206);
        expect(
          response.headers.value(HttpHeaders.contentRangeHeader),
          'bytes ${entry.$2}-${entry.$3}/100',
        );
        expect(
          await response.expand((bytes) => bytes).toList(),
          List.generate(entry.$3 - entry.$2 + 1, (i) => entry.$2 + i),
        );
      }
      expect(server.bytesServed, 18);
    },
  );

  test(
    'rejects invalid paths, hosts, methods and ranges before reading',
    () async {
      final server = await LocalMediaServer.start(
        size: 100,
        mimeType: 'video/mp4',
        read: (_, _) async => fail('No media read expected'),
      );
      addTearDown(server.close);
      for (final uri in [
        server.uri.replace(path: '/wrong'),
        server.uri.replace(query: 'x=1'),
      ]) {
        final response = await fetch(uri);
        expect(response.statusCode, 404);
        await response.drain<void>();
      }
      final wrongHost = await fetch(server.uri, host: 'example.test');
      expect(wrongHost.statusCode, 404);
      await wrongHost.drain<void>();
      final method = await fetch(server.uri, method: 'POST');
      expect(method.statusCode, 405);
      await method.drain<void>();
      for (final range in [
        'bytes=-0',
        'bytes=100-',
        'bytes=20-10',
        'bytes=0-1,2-3',
        'bytes=-',
        'bytes=999999999999999999999999-',
      ]) {
        final response = await fetch(server.uri, range: range);
        expect(response.statusCode, 416);
        expect(
          response.headers.value(HttpHeaders.contentRangeHeader),
          'bytes */100',
        );
        await response.drain<void>();
      }
      expect(server.ranges, isEmpty);
    },
  );

  test('streams full responses in bounded chunks', () async {
    final calls = <(int, int)>[];
    final size = LocalMediaServer.chunkSize + 3;
    final server = await LocalMediaServer.start(
      size: size,
      mimeType: 'video/mp4',
      read: (offset, count) async {
        calls.add((offset, count));
        return Uint8List(count);
      },
    );
    addTearDown(server.close);
    final response = await fetch(server.uri);
    expect(response.statusCode, 200);
    expect(response.contentLength, size);
    expect(
      await response.fold<int>(0, (sum, bytes) => sum + bytes.length),
      size,
    );
    expect(calls, [
      (0, LocalMediaServer.chunkSize),
      (LocalMediaServer.chunkSize, 3),
    ]);
  });

  test(
    'overlapping ranges complete without truncating an active response',
    () async {
      final size = 16 * LocalMediaServer.chunkSize;
      final server = await LocalMediaServer.start(
        size: size,
        mimeType: 'video/mp4',
        read: (_, count) async => Uint8List(count),
      );
      addTearDown(server.close);
      final first = await fetch(server.uri);
      final complete = first.fold<int>(0, (sum, bytes) => sum + bytes.length);
      final next = await fetch(server.uri, range: 'bytes=10-10');
      expect(await next.expand((bytes) => bytes).toList(), [0]);
      expect(await complete, size);
      expect(server.ranges.first['bytes'], size);
      expect(server.failedRequests, 0);
    },
  );

  test(
    'closing during a read stops further chunks and releases the endpoint',
    () async {
      final bytes = Completer<Uint8List>();
      final started = Completer<void>();
      var reads = 0;
      var cancellations = 0;
      final server = await LocalMediaServer.start(
        size: LocalMediaServer.chunkSize + 1,
        mimeType: 'video/mp4',
        read: (_, _) {
          reads++;
          started.complete();
          return bytes.future;
        },
        cancelRead: () {
          cancellations++;
          bytes.completeError(StateError('Read cancelled'));
        },
      );
      addTearDown(server.close);
      final pending = expectLater(
        fetch(server.uri).then((response) => response.drain<void>()),
        throwsA(anything),
      );
      await started.future;
      final queued = expectLater(
        fetch(
          server.uri,
          range: 'bytes=0-0',
        ).then((response) => response.drain<void>()),
        throwsA(anything),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(server.pendingRequests, 2);
      final closing = server.close();
      await closing;
      await pending;
      await queued;
      expect(reads, 1);
      expect(cancellations, 1);
      expect(server.bytesServed, 0);
      expect(server.failedRequests, 0);
      expect(server.pendingRequests, 0);
    },
  );

  test('queues native reads without cancelling an active range and rejects excess requests', () async {
    final bytes = Completer<Uint8List>();
    final started = Completer<void>();
    var reads = 0;
    final server = await LocalMediaServer.start(
      size: 1,
      mimeType: 'video/mp4',
      read: (_, _) {
        reads++;
        if (reads > 1) return Future.value(Uint8List.fromList([9]));
        started.complete();
        return bytes.future;
      },
    );
    addTearDown(server.close);
    final first = fetch(server.uri)
        .then((response) => response.expand((bytes) => bytes).toList());
    await started.future;
    final secondRequest = await client.getUrl(server.uri);
    secondRequest.headers.set(HttpHeaders.rangeHeader, 'bytes=0-0');
    final second = secondRequest.close();
    final third = fetch(server.uri);
    final fourth = fetch(server.uri);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(server.pendingRequests, 4);
    expect(server.queuedRequests, 2);
    expect(reads, 1);
    final excess = await fetch(server.uri);
    expect(excess.statusCode, 503);
    await excess.drain<void>();
    expect(server.rejectedRequests, 1);
    bytes.complete(Uint8List.fromList([7]));
    expect(await first, [7]);
    expect(await (await second).expand((bytes) => bytes).toList(), [9]);
    expect(await (await third).expand((bytes) => bytes).toList(), [9]);
    expect(await (await fourth).expand((bytes) => bytes).toList(), [9]);
    expect(reads, 4);
    await server.close();
    expect(server.pendingRequests, 0);
  });

  test(
    'shutdown rejects waiting responses without starting more native reads',
    () async {
      final started = Completer<void>();
      final bytes = Completer<Uint8List>();
      var reads = 0;
      final server = await LocalMediaServer.start(
        size: 1,
        mimeType: 'video/mp4',
        read: (_, _) {
          reads++;
          if (!started.isCompleted) started.complete();
          return bytes.future;
        },
        cancelRead: () => bytes.completeError(StateError('Closed')),
      );
      addTearDown(server.close);
      Future<bool> request() =>
          fetch(server.uri)
              .then((response) => response.drain<void>())
              .then((_) => true, onError: (Object _) => false);
      final first = request();
      await started.future;
      final rest = [request(), request(), request()];
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(server.pendingRequests, 4);
      await server.close();
      expect(await Future.wait([first, ...rest]), everyElement(isFalse));
      expect(server.pendingRequests, 0);
      expect(reads, 1);
    },
  );

  test(
    'abandons failed reads without manufacturing a successful body',
    () async {
      final server = await LocalMediaServer.start(
        size: 2,
        mimeType: 'video/mp4',
        read: (_, _) async => Uint8List(1),
      );
      addTearDown(server.close);
      await expectLater(
        fetch(server.uri).then((response) => response.drain<void>()),
        throwsA(anything),
      );
      expect(server.bytesServed, 0);
      expect(server.failedRequests, 1);
    },
  );

  for (final readingAudio in [false, true]) {
    test(
      'stream replacement cancels only its own native read (audio active: $readingAudio)',
      () async {
        final bytes = Completer<Uint8List>();
        final started = Completer<void>();
        var reads = 0;
        var cancellations = 0;
        final server = await LocalMediaServer.start(
          size: 1,
          mimeType: 'video/mp4',
          separateStreams: true,
          read: (_, _) {
            reads++;
            if (reads == 1) {
              started.complete();
              return bytes.future;
            }
            return Future.value(Uint8List.fromList([9]));
          },
          cancelRead: () {
            cancellations++;
            if (!bytes.isCompleted) {
              bytes.completeError(StateError('Superseded'));
            }
          },
        );
        addTearDown(server.close);
        final audio = server.uri.replace(path: '${server.uri.path}/audio');
        Future<int> request(Uri uri) => fetch(uri, range: 'bytes=0-0')
            .then((response) => response.expand((bytes) => bytes).single)
            .then((value) => value, onError: (Object _) => -1);
        final active = request(readingAudio ? audio : server.uri);
        await started.future;
        final other = request(readingAudio ? server.uri : audio);
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(cancellations, 0);
        expect(reads, 1);
        for (final entry in [('HEAD', null, 200), ('GET', 'bytes=1-0', 416)]) {
          final response = await fetch(
            server.uri,
            method: entry.$1,
            range: entry.$2,
          );
          expect(response.statusCode, entry.$3);
          await response.drain<void>();
        }
        final unknown = await fetch(
          server.uri.replace(path: '${server.uri.path}/other'),
        );
        expect(unknown.statusCode, 404);
        await unknown.drain<void>();
        expect(cancellations, 0);
        final replacement = request(server.uri);
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(cancellations, readingAudio ? 0 : 1);
        if (readingAudio) bytes.complete(Uint8List.fromList([7]));
        expect(await active, readingAudio ? 7 : -1);
        expect(await other, readingAudio ? -1 : 9);
        expect(await replacement, 9);
        expect(reads, readingAudio ? 2 : 3);
        expect(server.failedRequests, 0);
        expect(server.rejectedRequests, 0);
      },
    );
  }

  test('an overlapping range preserves the first read and only shutdown cancels native work', () async {
    final bytes = Completer<Uint8List>();
    final started = Completer<void>();
    var reads = 0;
    var cancellations = 0;
    final server = await LocalMediaServer.start(
      size: 1,
      mimeType: 'video/mp4',
      read: (_, _) {
        reads++;
        if (reads > 1) return Future.value(Uint8List.fromList([9]));
        started.complete();
        return bytes.future;
      },
      cancelRead: () {
        cancellations++;
        if (!bytes.isCompleted) {
          bytes.completeError(StateError('Read superseded'));
        }
      },
    );
    addTearDown(server.close);
    final first = fetch(server.uri)
        .then((response) => response.expand((bytes) => bytes).toList());
    await started.future;
    final next = await client.getUrl(server.uri);
    next.headers.set(HttpHeaders.rangeHeader, 'bytes=0-0');
    final second = next.close();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(cancellations, 0);
    expect(reads, 1);
    bytes.complete(Uint8List.fromList([7]));
    expect(await first, [7]);
    expect(await (await second).expand((bytes) => bytes).toList(), [9]);
    expect(cancellations, 0);
    expect(server.failedRequests, 0);
    expect(reads, 2);
    await server.close();
    expect(cancellations, 1);
  });

  test(
    'overlapping responses reserve the byte budget before awaiting reads',
    () async {
      final started = Completer<void>();
      final bytes = Completer<Uint8List>();
      final server = await LocalMediaServer.start(
        size: 8,
        mimeType: 'video/mp4',
        maxBytes: 6,
        read: (_, count) {
          if (!started.isCompleted) {
            started.complete();
            return bytes.future;
          }
          return Future.value(Uint8List(count));
        },
      );
      addTearDown(server.close);
      final first = fetch(
        server.uri,
        range: 'bytes=0-3',
      ).then((response) => response.drain<void>());
      await started.future;
      await expectLater(
        fetch(
          server.uri,
          range: 'bytes=4-7',
        ).then((response) => response.drain<void>()),
        throwsA(anything),
      );
      bytes.complete(Uint8List(4));
      await first;
      final remaining = await fetch(server.uri, range: 'bytes=4-5');
      expect(
        await remaining.fold<int>(0, (sum, bytes) => sum + bytes.length),
        2,
      );
      expect(server.bytesServed, 6);
      expect(server.failedRequests, 0);
    },
  );
}
