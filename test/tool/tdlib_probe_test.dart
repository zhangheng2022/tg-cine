import 'dart:async';
import 'dart:collection';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/support/tdlib_probe.dart';

void main() {
  test(
    'one receive pump routes reversed responses and preserves updates in order',
    () async {
      final queue = Queue<Map<String, dynamic>>();
      final sent = <Map<String, dynamic>>[];
      final dispatcher = TdlibDispatcher(
        clientId: 1,
        send: sent.add,
        receive: () => queue.isEmpty ? null : queue.removeFirst(),
      );
      addTearDown(dispatcher.dispose);
      final events = <String>[];
      final subscription = dispatcher.events.listen(
        (event) => events.add(event['@type'] as String),
      );
      addTearDown(subscription.cancel);
      final first = dispatcher.request({
        '@type': 'prefix',
      }, timeout: const Duration(seconds: 1));
      final second = dispatcher.request({
        '@type': 'read',
      }, timeout: const Duration(seconds: 1));
      queue.addAll([
        {'@client_id': 2, '@extra': sent.first['@extra'], '@type': 'foreign'},
        {'@client_id': 1, '@type': 'update-first'},
        {
          '@client_id': 1,
          '@extra': sent.last['@extra'],
          '@type': 'read-result',
        },
        {'@client_id': 1, '@type': 'update-last'},
        {
          '@client_id': 1,
          '@extra': sent.first['@extra'],
          '@type': 'prefix-result',
        },
      ]);
      expect((await second)['@type'], 'read-result');
      expect((await first)['@type'], 'prefix-result');
      expect(events, [
        'update-first',
        'read-result',
        'update-last',
        'prefix-result',
      ]);
    },
  );
  test(
    'continuous updates yield to other IO after at most 32 receives',
    () async {
      var calls = 0;
      var ready = false;
      final dispatcher = TdlibDispatcher(
        clientId: 1,
        send: (_) {},
        receive: () {
          if (++calls == 1) Timer.run(() => ready = true);
          return {
            '@client_id': 1,
            '@type': ready ? 'ok' : 'update',
            if (ready) '@extra': 1,
          };
        },
      );
      addTearDown(dispatcher.dispose);
      expect(
        (await dispatcher.request({
          '@type': 'test',
        }, timeout: const Duration(seconds: 1)))['@type'],
        'ok',
      );
      expect(calls, greaterThan(32));
    },
  );
  test(
    'timeout ignores late replies without completing another request',
    () async {
      final queue = Queue<Map<String, dynamic>>();
      final dispatcher = TdlibDispatcher(
        clientId: 1,
        send: (_) {},
        receive: () => queue.isEmpty ? null : queue.removeFirst(),
      );
      addTearDown(dispatcher.dispose);
      await expectLater(
        dispatcher.request({}, timeout: const Duration(milliseconds: 20)),
        throwsA(isA<TimeoutException>()),
      );
      final next = dispatcher.request({}, timeout: const Duration(seconds: 1));
      queue.addAll([
        {'@client_id': 1, '@extra': 1, '@type': 'late'},
        {'@client_id': 1, '@extra': 2, '@type': 'current'},
      ]);
      expect((await next)['@type'], 'current');
    },
  );
  test(
    'bounds outstanding requests and fails pending work on disposal',
    () async {
      var sent = 0;
      final dispatcher = TdlibDispatcher(
        clientId: 1,
        send: (_) => sent++,
        receive: () => null,
      );
      final pending = [
        for (var i = 0; i < 64; i++)
          expectLater(
            dispatcher.request({}, timeout: const Duration(seconds: 1)),
            throwsStateError,
          ),
      ];
      await expectLater(
        dispatcher.request({}, timeout: const Duration(seconds: 1)),
        throwsStateError,
      );
      expect(sent, 64);
      await dispatcher.dispose();
      await Future.wait(pending);
      await expectLater(
        dispatcher.request({}, timeout: const Duration(seconds: 1)),
        throwsStateError,
      );
      await dispatcher.dispose();
    },
  );
  test('native errors omit private messages and malformed errors do not strand a request', () async {
    final queue = Queue<Map<String, dynamic>>();
    final dispatcher = TdlibDispatcher(
      clientId: 1,
      send: (_) {},
      receive: () => queue.isEmpty ? null : queue.removeFirst(),
    );
    addTearDown(dispatcher.dispose);
    final first = dispatcher.request({}, timeout: const Duration(seconds: 1));
    queue.add({
      '@client_id': 1,
      '@extra': 1,
      '@type': 'error',
      'code': 404,
      'message': 'private-path-and-account',
    });
    await expectLater(
      first,
      throwsA(
        isA<TdlibRequestError>().having(
          (error) => error.toString(),
          'safe message',
          isNot(contains('private')),
        ),
      ),
    );
    final second = dispatcher.request({}, timeout: const Duration(seconds: 1));
    queue.add({
      '@client_id': 1,
      '@extra': 2,
      '@type': 'error',
      'code': 'invalid',
    });
    await expectLater(second, throwsStateError);
  });
  test('native send and receive failures release pending requests', () async {
    final sender = TdlibDispatcher(
      clientId: 1,
      send: (_) => throw StateError('private'),
      receive: () => null,
    );
    await expectLater(
      sender.request({}, timeout: const Duration(seconds: 1)),
      throwsStateError,
    );
    await sender.dispose();
    final receiver = TdlibDispatcher(
      clientId: 1,
      send: (_) {},
      receive: () => throw StateError('private'),
    );
    await expectLater(
      receiver.request({}, timeout: const Duration(seconds: 1)),
      throwsStateError,
    );
    await receiver.dispose();
  });
}
