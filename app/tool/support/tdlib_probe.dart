// TDLib's JSON C interface is documented in td/telegram/td_json_client.h (BSL-1.0).
import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

class TdlibRequestError implements Exception {
  const TdlibRequestError(this.code);
  final int code;

  @override
  String toString() => 'TDLib request failed ($code)';
}

/// One receive pump matches bounded concurrent RPCs without serializing local reads.
class TdlibDispatcher {
  TdlibDispatcher({
    required this.clientId,
    required this.send,
    required this.receive,
  }) {
    _poll = Timer.periodic(const Duration(milliseconds: 5), (_) => _drain());
  }

  final int clientId;
  final void Function(Map<String, dynamic>) send;
  final Map<String, dynamic>? Function() receive;
  final _events = StreamController<Map<String, dynamic>>.broadcast(sync: true);
  final _pending = <int, (Completer<Map<String, dynamic>>, Timer)>{};
  late final Timer _poll;
  int _nextId = 0;
  bool _closed = false;
  Stream<Map<String, dynamic>> get events => _events.stream;

  Future<Map<String, dynamic>> request(
    Map<String, dynamic> value, {
    required Duration timeout,
  }) {
    if (_closed || _pending.length >= 64) {
      return Future.error(StateError('Native dispatcher closed or busy'));
    }
    final id = ++_nextId;
    final result = Completer<Map<String, dynamic>>();
    final timer = Timer(timeout, () {
      if (_pending.remove(id) != null) {
        result.completeError(TimeoutException('TDLib probe timed out'));
      }
    });
    _pending[id] = (result, timer);
    try {
      send({...value, '@extra': id});
    } catch (_) {
      _pending.remove(id);
      timer.cancel();
      result.completeError(StateError('Native send failed'));
    }
    return result.future;
  }

  void _drain() {
    try {
      for (var count = 0; count < 32 && !_closed; count++) {
        final event = receive();
        if (event == null) break;
        if (event['@client_id'] != clientId) continue;
        _events.add(event);
        final pending = _pending.remove(event['@extra']);
        if (pending == null) continue;
        pending.$2.cancel();
        if (event['@type'] == 'error') {
          // Native messages may contain paths or account details.
          final code = event['code'];
          pending.$1.completeError(
            code is int
                ? TdlibRequestError(code)
                : StateError('Invalid native error'),
          );
        } else {
          pending.$1.complete(event);
        }
      }
    } catch (_) {
      unawaited(dispose());
    }
  }

  Future<void> dispose() async {
    if (_closed) return;
    _closed = true;
    _poll.cancel();
    for (final pending in _pending.values) {
      pending.$2.cancel();
      pending.$1.completeError(StateError('Native dispatcher closed'));
    }
    _pending.clear();
    await _events.close();
  }
}

/// A single-client probe; do not run another td_receive consumer in this process.
class TdlibProbe {
  TdlibProbe(String path) {
    final library = DynamicLibrary.open(File(path).absolute.path);
    _execute = library
        .lookupFunction<
          Pointer<Utf8> Function(Pointer<Utf8>),
          Pointer<Utf8> Function(Pointer<Utf8>)
        >('td_execute');
    _send = library
        .lookupFunction<
          Void Function(Int32, Pointer<Utf8>),
          void Function(int, Pointer<Utf8>)
        >('td_send');
    _receive = library
        .lookupFunction<
          Pointer<Utf8> Function(Double),
          Pointer<Utf8> Function(double)
        >('td_receive');
    sync({
      '@type': 'setLogStream',
      'log_stream': {'@type': 'logStreamEmpty'},
    });
    sync({'@type': 'setLogVerbosityLevel', 'new_verbosity_level': 0});
    clientId = library.lookupFunction<Int32 Function(), int Function()>(
      'td_create_client_id',
    )();
    if (clientId <= 0) throw StateError('Invalid client identifier');
    _dispatcher = TdlibDispatcher(
      clientId: clientId,
      send: (request) {
        final data = jsonEncode(request).toNativeUtf8();
        try {
          _send(clientId, data);
        } finally {
          malloc.free(data);
        }
      },
      receive: () {
        final response = _receive(0);
        if (response == nullptr) return null;
        // Copy before the next receive/execute invalidates the native pointer.
        final event =
            jsonDecode(response.toDartString()) as Map<String, dynamic>;
        recentResponses.add({
          'type': event['@type'],
          'matchedClient': event['@client_id'] == clientId,
          if (event['@extra'] is int) 'requestId': event['@extra'],
        });
        if (recentResponses.length > 16) recentResponses.removeAt(0);
        return event;
      },
    );
    _updates = _dispatcher.events.listen((event) {
      if (event['@type'] == 'updateAuthorizationState') {
        _state = (event['authorization_state'] as Map?)?['@type'] as String?;
      }
    });
  }

  late final Pointer<Utf8> Function(Pointer<Utf8>) _execute;
  late final void Function(int, Pointer<Utf8>) _send;
  late final Pointer<Utf8> Function(double) _receive;
  late final int clientId;
  late final TdlibDispatcher _dispatcher;
  late final StreamSubscription<Map<String, dynamic>> _updates;
  String? _state;
  final recentResponses = <Map<String, dynamic>>[];

  Map<String, dynamic> sync(Map<String, dynamic> request) {
    final data = jsonEncode(request).toNativeUtf8();
    try {
      final response = _execute(data);
      if (response == nullptr) throw StateError('No native response');
      return jsonDecode(response.toDartString()) as Map<String, dynamic>;
    } finally {
      malloc.free(data);
    }
  }

  Future<Map<String, dynamic>> request(
    Map<String, dynamic> request, {
    Duration timeout = const Duration(seconds: 5),
  }) => _dispatcher.request(request, timeout: timeout);

  /// Queues pre-initialization controls before parameters without waiting for them.
  Future<List<Map<String, dynamic>>> initialize(
    List<Map<String, dynamic>> requests,
  ) async {
    if (requests.isEmpty) {
      throw StateError('Invalid initialization');
    }
    return Future.wait(
      requests.map(
        (value) => request(value, timeout: const Duration(seconds: 15)),
      ),
    );
  }

  Future<void> awaitState(String state) async {
    if (_state == state) return;
    await _dispatcher.events
        .firstWhere((_) => _state == state)
        .timeout(const Duration(seconds: 5));
  }

  Future<void> close() async {
    try {
      if (_state != 'authorizationStateClosed') {
        await request({'@type': 'close'});
        await awaitState('authorizationStateClosed');
      }
    } finally {
      await _updates.cancel();
      await _dispatcher.dispose();
    }
  }
}
