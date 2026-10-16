import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'playback_trace.dart';

/// Private, bounded loopback endpoint for the native decoder.
class LocalMediaServer {
  static const chunkSize = 64 * 1024;
  static const maxRecordedRanges = 256;
  LocalMediaServer._(
    this._server,
    this.size,
    this.mimeType,
    this.read,
    this.cancelRead,
    this.maxBytes,
    this.maxRanges,
    this.separateStreams,
    this.trace,
    this.readReady,
  ) : _path =
          '/${base64UrlEncode(List.generate(24, (_) => Random.secure().nextInt(256)))}' {
    _server.autoCompress = false;
    _subscription = _server.listen((request) {
      if ((request.uri.path != _path &&
              !(separateStreams && request.uri.path == '$_path/audio')) ||
          request.uri.hasQuery ||
          request.headers[HttpHeaders.hostHeader]?.join(',') != uri.authority) {
        request.response.statusCode = HttpStatus.notFound;
        unawaited(
          request.response.close().then<void>((_) {}, onError: (Object _) {}),
        );
        return;
      }
      if (request.method != 'GET' || _range(request) == null) {
        unawaited(_serve(request));
        return;
      }
      if (separateStreams) {
        final previous = _streams[request.uri.path];
        if (previous != null) {
          _superseded.add(previous.response);
          previous.response.deadline = Duration.zero;
          if (identical(_readingResponse, previous.response)) {
            cancelRead?.call();
          }
          if (_waiting.remove(previous)) {
            _superseded.remove(previous.response);
            unawaited(
              previous.response.close().then<void>(
                (_) {},
                onError: (Object _) {},
              ),
            );
          }
        }
        _streams[request.uri.path] = request;
      }
      if (_queued >= 2) {
        if (_waiting.length < 2) {
          _waiting.add(request);
          queuedRequests++;
          return;
        }
        rejectedRequests++;
        request.response.statusCode = HttpStatus.serviceUnavailable;
        unawaited(
          request.response.close().then<void>((_) {}, onError: (Object _) {}),
        );
        return;
      }
      _startResponse(request);
    });
  }

  final HttpServer _server;
  final int size;
  final String mimeType;
  final Future<Uint8List> Function(int, int) read;
  final Future<Uint8List?> Function(int, int)? readReady;
  final void Function()? cancelRead;
  final int? maxBytes;
  final int? maxRanges;
  final bool separateStreams;
  final PlaybackTrace? trace;
  final String _path;
  late final StreamSubscription<HttpRequest> _subscription;
  final _requests = <Future<void>>{};
  final _waiting = <HttpRequest>[];
  final _streams = <String, HttpRequest>{};
  final _superseded = <HttpResponse>{};
  HttpResponse? _readingResponse;
  Future<void> _readTail = Future<void>.value();
  int _queued = 0;
  int _reservedBytes = 0;
  bool _closed = false;
  int bytesServed = 0;
  int rangeRequests = 0;
  int failedRequests = 0;
  int queuedRequests = 0;
  int rejectedRequests = 0;
  final ranges = <Map<String, int>>[];
  bool get budgetExhausted =>
      (maxBytes != null && bytesServed >= maxBytes!) ||
      (maxRanges != null && rangeRequests >= maxRanges!);
  int get pendingRequests => _queued + _waiting.length;

  void _startResponse(HttpRequest request) {
    _queued++;
    final serving = _serve(request).whenComplete(() {
      if (identical(_streams[request.uri.path], request)) {
        _streams.remove(request.uri.path);
      }
      _superseded.remove(request.response);
      _queued--;
      if (!_closed && _waiting.isNotEmpty) {
        _startResponse(_waiting.removeAt(0));
      }
    });
    _requests.add(serving);
    unawaited(serving.whenComplete(() => _requests.remove(serving)));
  }

  Uri get uri =>
      Uri(scheme: 'http', host: '127.0.0.1', port: _server.port, path: _path);

  static Future<LocalMediaServer> start({
    required int size,
    required String mimeType,
    required Future<Uint8List> Function(int, int) read,
    Future<Uint8List?> Function(int, int)? readReady,
    void Function()? cancelRead,
    int? maxBytes = 32 * 1024 * 1024,
    int? maxRanges = 64,
    bool separateStreams = false,
    PlaybackTrace? trace,
  }) async {
    if (size <= 0 ||
        (maxBytes != null &&
            (maxBytes <= 0 || maxBytes > 8 * 1024 * 1024 * 1024)) ||
        (maxRanges != null && (maxRanges <= 0 || maxRanges > 8192)) ||
        !RegExp(r'^(video/[a-zA-Z0-9.+-]+|application/octet-stream)$')
            .hasMatch(mimeType)) {
      throw const FormatException('Invalid local media');
    }
    return LocalMediaServer._(
      await HttpServer.bind(InternetAddress.loopbackIPv4, 0),
      size,
      mimeType,
      read,
      cancelRead,
      maxBytes,
      maxRanges,
      separateStreams,
      trace,
      readReady,
    );
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _waiting.clear();
    _streams.clear();
    cancelRead?.call();
    await _server.close(force: true);
    await _subscription.cancel();
    await Future.wait(_requests.toList());
  }

  // Available reads share the receive pump; only cold downloads use this queue.
  Future<Uint8List> _readChunk(
    HttpResponse response,
    int offset,
    int count,
  ) async {
    if (_closed || _superseded.contains(response)) {
      throw StateError('Media endpoint closed or superseded');
    }
    final ready = await readReady?.call(offset, count);
    if (ready != null) return ready;
    final queued = Stopwatch()..start();
    final result = _readTail.then((_) async {
      if (_closed || _superseded.contains(response)) {
        throw StateError('Media endpoint closed or superseded');
      }
      _readingResponse = response;
      trace?.record(
        PlaybackStage.httpQueue,
        offset: offset,
        durationUs: queued.elapsedMicroseconds,
      );
      try {
        return await read(offset, count);
      } finally {
        _readingResponse = null;
      }
    });
    _readTail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  (int, int)? _range(HttpRequest request) {
    final headers = request.headers[HttpHeaders.rangeHeader];
    if (headers == null) return (0, size - 1);
    final match = headers.length == 1
        ? RegExp(r'^bytes=(\d*)-(\d*)$').firstMatch(headers.single)
        : null;
    if (match == null || (match[1]!.isEmpty && match[2]!.isEmpty)) return null;
    var start = 0;
    var end = size - 1;
    if (match[1]!.isEmpty) {
      final suffix = int.tryParse(match[2]!);
      start = suffix == null || suffix <= 0 ? size : max(0, size - suffix);
    } else {
      start = int.tryParse(match[1]!) ?? size;
      end = match[2]!.isEmpty
          ? size - 1
          : min(int.tryParse(match[2]!) ?? -1, size - 1);
    }
    return start >= size || end < start ? null : (start, end);
  }

  Future<void> _serve(HttpRequest request) async {
    final response = request.response;
    var mediaFailure = false;
    try {
      if (_closed || _superseded.contains(response)) return;
      response.headers
        ..set(HttpHeaders.cacheControlHeader, 'no-store')
        ..set('X-Content-Type-Options', 'nosniff');
      if (request.method != 'GET' && request.method != 'HEAD') {
        response.statusCode = HttpStatus.methodNotAllowed;
        response.headers.set(HttpHeaders.allowHeader, 'GET, HEAD');
        return;
      }
      final parsed = _range(request);
      if (parsed == null) {
        response.statusCode = HttpStatus.requestedRangeNotSatisfiable;
        response.headers.set(HttpHeaders.contentRangeHeader, 'bytes */$size');
        return;
      }
      final (start, end) = parsed;
      if (request.headers[HttpHeaders.rangeHeader] != null) {
        response.statusCode = HttpStatus.partialContent;
        response.headers.set(
          HttpHeaders.contentRangeHeader,
          'bytes $start-$end/$size',
        );
      }
      response.headers
        ..set(HttpHeaders.acceptRangesHeader, 'bytes')
        ..set(HttpHeaders.contentTypeHeader, mimeType);
      response.contentLength = end - start + 1;
      if (request.method == 'HEAD') return;
      if (budgetExhausted) {
        response.statusCode = HttpStatus.serviceUnavailable;
        response.contentLength = 0;
        return;
      }
      final range = {
        'offset': start,
        'end': end,
        'bytes': 0,
        'stream': request.uri.path == _path ? 0 : 1,
      };
      rangeRequests++;
      // Retain recent diagnostics without making their capacity a playback quota.
      if (ranges.length == maxRecordedRanges) ranges.removeAt(0);
      ranges.add(range);
      for (var offset = start; offset <= end;) {
        if (_closed ||
            _superseded.contains(response) ||
            response.connectionInfo == null) {
          return;
        }
        final count = min(chunkSize, end - offset + 1);
        if (maxBytes != null &&
            bytesServed + _reservedBytes + count > maxBytes!) {
          throw StateError('Decoder probe byte budget exceeded');
        }
        var reserved = count;
        _reservedBytes += count;
        try {
          late final Uint8List bytes;
          final reading = Stopwatch()..start();
          try {
            bytes = await _readChunk(response, offset, count);
            trace?.record(
              PlaybackStage.httpRead,
              offset: offset,
              bytes: bytes.length,
              stream: range['stream'],
              durationUs: reading.elapsedMicroseconds,
            );
          } catch (_) {
            mediaFailure = true;
            rethrow;
          }
          if (_closed ||
              _superseded.contains(response) ||
              response.connectionInfo == null) {
            return;
          }
          if (bytes.length != count) {
            mediaFailure = true;
            throw StateError('Incomplete decoder range');
          }
          for (var position = 0; position < bytes.length;) {
            if (_closed ||
                _superseded.contains(response) ||
                response.connectionInfo == null) {
              return;
            }
            final length = min(16 * 1024, bytes.length - position);
            response.add(
              Uint8List.sublistView(bytes, position, position + length),
            );
            // Charge queued bytes even if the decoder closes its socket during flush.
            bytesServed += length;
            range['bytes'] = range['bytes']! + length;
            _reservedBytes -= length;
            reserved -= length;
            final flushing = Stopwatch()..start();
            await response.flush();
            trace?.record(
              PlaybackStage.httpFlush,
              bytes: length,
              stream: range['stream'],
              durationUs: flushing.elapsedMicroseconds,
            );
            position += length;
          }
          await Future<void>.delayed(Duration.zero);
        } finally {
          _reservedBytes -= reserved;
        }
        offset += count;
      }
    } catch (_) {
      if (!_closed && !_superseded.contains(response) && mediaFailure) {
        failedRequests++;
      }
      // Abandon a truncated response; never turn missing bytes into video data.
      response.deadline = Duration.zero;
    } finally {
      try {
        await response.close();
      } catch (_) {}
    }
  }
}
