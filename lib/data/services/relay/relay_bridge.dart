import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

/// Loopback-only SOCKS5 bridge with bounded per-connection flow control.
class RelayBridge {
  RelayBridge._(
    this._server,
    this._relay,
    this._token,
    this._targets,
    this._accessToken,
    this._resolveTarget,
  ) {
    _subscription = _server.listen((socket) {
      _clients.add(socket);
      unawaited(_serve(socket));
    });
  }

  final ServerSocket _server;
  final Uri _relay;
  final String _token;
  final Future<String> Function()? _accessToken;
  final Future<String?> Function(String host, int port)? _resolveTarget;
  final Map<(String, int), String> _targets;
  final _clients = <Socket>{};
  final _webSockets = <WebSocket>{};
  final HttpClient _httpClient = HttpClient();
  late final StreamSubscription<Socket> _subscription;
  bool _closed = false;
  (String, int)? _lastRejectedTarget;
  final _connectionFailures = <int, int>{};
  Map<int, int> get connectionFailures => Map.unmodifiable(_connectionFailures);
  final _traffic = <String, Map<String, int>>{};
  final _traceIds = <String>[];
  List<String> get traceIds => List.unmodifiable(_traceIds);

  int get port => _server.port;
  (String, int)? get lastRejectedTarget => _lastRejectedTarget;
  int get activeConnections => _clients.length;
  Map<String, Map<String, int>> get traffic => {
    for (final entry in _traffic.entries) entry.key: Map.of(entry.value),
  };

  static Future<RelayBridge> start({
    required Uri relay,
    String token = '',
    Future<String> Function()? accessToken,
    Map<(String, int), String> targets = const {},
    Future<String?> Function(String host, int port)? resolveTarget,
  }) async {
    if (!(relay.scheme == 'wss' ||
            (relay.scheme == 'ws' && relay.host == '127.0.0.1')) ||
        relay.userInfo.isNotEmpty ||
        relay.hasQuery ||
        relay.hasFragment ||
        relay.path != '/v2/tunnel' ||
        (token.isEmpty && accessToken == null) ||
        RegExp(r'\s').hasMatch(token) ||
        (targets.isEmpty && resolveTarget == null) ||
        targets.entries.any(
          (entry) =>
              entry.key.$1.isEmpty ||
              entry.key.$2 < 1 ||
              entry.key.$2 > 65535 ||
              !RegExp(r'^[a-zA-Z0-9_-]{1,64}$').hasMatch(entry.value),
        )) {
      throw ArgumentError('Invalid relay bridge configuration');
    }
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    return RelayBridge._(
      server,
      relay,
      token,
      Map.unmodifiable(targets),
      accessToken,
      resolveTarget,
    );
  }

  Future<void> close() async {
    _closed = true;
    _httpClient.close(force: true);
    await _subscription.cancel();
    await _server.close();
    for (final client in _clients.toList()) {
      client.destroy();
    }
    await Future.wait(_webSockets.toList().map((socket) => socket.close()));
  }

  Future<void> _serve(Socket client) async {
    final input = _SocketInput(client);
    WebSocket? upstream;
    StreamIterator<dynamic>? messages;
    Future<void>? downloading;
    var connected = false;
    var finished = false;
    try {
      final greeting = await input.read(2);
      if (greeting[0] != 5 || greeting[1] == 0) return;
      final methods = await input.read(greeting[1]);
      client.add([5, methods.contains(0) ? 0 : 255]);
      await client.flush();
      if (!methods.contains(0)) return;
      final request = await input.read(4);
      if (request[0] != 5 || request[1] != 1 || request[2] != 0) {
        throw const FormatException('SOCKS CONNECT required');
      }
      final String host;
      switch (request[3]) {
        case 1:
          host = (await input.read(4)).join('.');
        case 3:
          host = ascii.decode(await input.read((await input.read(1))[0]));
        case 4:
          host = InternetAddress.fromRawAddress(await input.read(16)).address;
        default:
          throw const FormatException('Invalid address');
      }
      final port = await input.read(2);
      final address = (host, (port[0] << 8) | port[1]);
      final target = _resolveTarget != null
          ? await _resolveTarget(host, address.$2)
          : _targets[address];
      if (target == null) {
        _lastRejectedTarget = address;
        client.add([5, 2, 0, 1, 0, 0, 0, 0, 0, 0]);
        await client.flush();
        return;
      }
      final counters = _traffic.putIfAbsent(
        target,
        () => {
          'uploadedBytes': 0,
          'downloadedBytes': 0,
          'connections': 0,
          'idleTimeouts': 0,
          'downFrames': 0,
          'downWriteUs': 0,
          'maxDownWriteUs': 0,
          'upAckCount': 0,
          'upAckUs': 0,
          'maxUpAckUs': 0,
          'byteLimits': 0,
          'sessionLimits': 0,
          'ackTimeouts': 0,
        },
      );
      counters['connections'] = counters['connections']! + 1;
      final traceId = base64UrlEncode(
        List.generate(24, (_) => Random.secure().nextInt(256)),
      );
      if (_traceIds.length < 512) _traceIds.add(traceId);
      final connection = WebSocket.connect(
        _relay
            .replace(queryParameters: {'v': '2', 'target': target})
            .toString(),
        headers: {
          'Authorization': 'Bearer ${await _accessToken?.call() ?? _token}',
          'X-TG-Cine-Trace': traceId,
        },
        customClient: _httpClient,
      );
      unawaited(
        connection.then((socket) {
          if (finished || _closed) unawaited(socket.close());
        }, onError: (Object _) {}),
      );
      // Edge policy refresh and upstream TCP dial can each take five seconds.
      upstream = await connection.timeout(const Duration(seconds: 15));
      if (_closed) return;
      _webSockets.add(upstream);
      upstream.pingInterval = const Duration(seconds: 15);
      messages = StreamIterator(upstream);
      final incoming = messages;
      client.add([5, 0, 0, 1, 127, 0, 0, 1, 0, 0]);
      await client.flush();
      connected = true;

      final ws = upstream;
      // v2 allows 256 KiB in flight; four bounded frames avoid one RTT per small RPC.
      final pendingAcks = <(Completer<void>, Stopwatch, Timer)>[];
      Future<void> upload() async {
        await for (final bytes in input.remaining()) {
          for (var offset = 0; offset < bytes.length; offset += 65536) {
            while (pendingAcks.length >= 4) {
              await pendingAcks.first.$1.future;
            }
            final ack = Completer<void>();
            // A peer can close before upload reaches the wait for this frame.
            ack.future.ignore();
            final confirming = Stopwatch()..start();
            final timeout = Timer(const Duration(seconds: 30), () {
              if (!ack.isCompleted) {
                ack.completeError(
                  TimeoutException('Relay acknowledgement timed out'),
                );
                client.destroy();
              }
            });
            pendingAcks.add((ack, confirming, timeout));
            final end = (offset + 65536).clamp(0, bytes.length);
            ws.add(Uint8List.sublistView(bytes, offset, end));
            counters['uploadedBytes'] =
                counters['uploadedBytes']! + end - offset;
          }
        }
        while (pendingAcks.isNotEmpty) {
          await pendingAcks.first.$1.future;
        }
      }

      Future<void> download() async {
        try {
          while (await incoming.moveNext()) {
            final frame = incoming.current;
            if (frame == 'ACK' && pendingAcks.isNotEmpty) {
              final ack = pendingAcks.removeAt(0);
              ack.$3.cancel();
              final elapsed = ack.$2.elapsedMicroseconds;
              counters['upAckCount'] = counters['upAckCount']! + 1;
              counters['upAckUs'] = counters['upAckUs']! + elapsed;
              if (elapsed > counters['maxUpAckUs']!) {
                counters['maxUpAckUs'] = elapsed;
              }
              if (!ack.$1.isCompleted) ack.$1.complete();
            } else if (frame is List<int> &&
                frame.isNotEmpty &&
                frame.length <= 65536) {
              final writing = Stopwatch()..start();
              client.add(frame);
              counters['downloadedBytes'] =
                  counters['downloadedBytes']! + frame.length;
              await client.flush();
              final elapsed = writing.elapsedMicroseconds;
              counters['downFrames'] = counters['downFrames']! + 1;
              counters['downWriteUs'] = counters['downWriteUs']! + elapsed;
              if (elapsed > counters['maxDownWriteUs']!) {
                counters['maxDownWriteUs'] = elapsed;
              }
              ws.add('ACK');
            } else {
              throw const FormatException('Invalid relay frame');
            }
          }
        } finally {
          if (ws.closeReason == 'IDLE_TIMEOUT') {
            counters['idleTimeouts'] = counters['idleTimeouts']! + 1;
          }
          final reasonCounter = switch (ws.closeReason) {
            'BYTE_LIMIT' => 'byteLimits',
            'SESSION_LIMIT' => 'sessionLimits',
            'ACK_TIMEOUT' => 'ackTimeouts',
            _ => null,
          };
          if (reasonCounter != null) {
            counters[reasonCounter] = counters[reasonCounter]! + 1;
          }
          // Release a sender waiting for confirmation when the relay disappears.
          for (final ack in pendingAcks) {
            ack.$3.cancel();
            if (!ack.$1.isCompleted) {
              ack.$1.completeError(const SocketException('Relay closed'));
            }
          }
          pendingAcks.clear();
        }
      }

      downloading = download();
      await Future.any([upload(), downloading]);
    } catch (error) {
      if (!connected && !_closed) {
        final status = error is WebSocketException
            ? error.httpStatusCode ?? 0
            : 0;
        _connectionFailures.update(
          status,
          (count) => count + 1,
          ifAbsent: () => 1,
        );
        try {
          client.add([5, 1, 0, 1, 0, 0, 0, 0, 0, 0]);
          await client.flush();
        } catch (_) {
          // The local caller can already have disconnected.
        }
      }
    } finally {
      finished = true;
      _clients.remove(client);
      client.destroy();
      await input.cancel();
      if (upstream != null) {
        _webSockets.remove(upstream);
        await upstream.close();
      }
      // Keep reading until the peer's close frame; canceling first leaves Dart's TCP read side open.
      try {
        await downloading?.timeout(const Duration(seconds: 6));
      } catch (_) {
        // The transport can already have failed.
      }
      await messages?.cancel();
    }
  }
}

class _SocketInput {
  _SocketInput(Socket socket) : _iterator = StreamIterator(socket);

  final StreamIterator<Uint8List> _iterator;
  Uint8List _buffer = Uint8List(0);
  int _offset = 0;

  Future<Uint8List> read(int count) async {
    final result = Uint8List(count);
    var filled = 0;
    while (filled < count) {
      if (_offset == _buffer.length) {
        if (!await _iterator.moveNext().timeout(const Duration(seconds: 10))) {
          throw const SocketException('Local connection closed');
        }
        _buffer = _iterator.current;
        _offset = 0;
      }
      final length = (count - filled).clamp(0, _buffer.length - _offset);
      result.setRange(filled, filled + length, _buffer, _offset);
      _offset += length;
      filled += length;
    }
    return result;
  }

  Stream<Uint8List> remaining() async* {
    if (_offset < _buffer.length) yield Uint8List.sublistView(_buffer, _offset);
    while (await _iterator.moveNext()) {
      yield _iterator.current;
    }
  }

  Future<void> cancel() => _iterator.cancel();
}
