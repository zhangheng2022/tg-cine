import 'dart:io';

import 'package:tg_cine/data/services/relay/relay_bridge.dart';

import 'relay_bridge.dart' as bridge_tool;
import 'support/tdlib_probe.dart';

/// Checks TDLib's real MTProto handshake through the deployed bridge, pre-login.
Future<void> main(List<String> arguments) async {
  if (arguments.length != 2) {
    stderr.writeln(
      'Usage: dart run tool/verify_tdlib_relay.dart <tdjson-library> <local-config.json>',
    );
    exitCode = 64;
    return;
  }
  RelayBridge? bridge;
  TdlibProbe? client;
  try {
    bridge = await bridge_tool.startConfiguredBridge(arguments[1]);
    client = TdlibProbe(arguments[0]);
    await client.request({'@type': 'getAuthorizationState'});
    await client.awaitState('authorizationStateWaitTdlibParameters');
    for (var dc = 1; dc <= 5; dc++) {
      final elapsed = Stopwatch()..start();
      final response = await client.request({
        '@type': 'testProxy',
        'proxy': {
          '@type': 'proxy',
          'server': '127.0.0.1',
          'port': bridge.port,
          'type': {'@type': 'proxyTypeSocks5', 'username': '', 'password': ''},
        },
        'dc_id': dc,
        'timeout': 20.0,
      }, timeout: const Duration(seconds: 22));
      if (response['@type'] != 'ok') throw StateError('Unexpected response');
      stdout.writeln(
        'TDLib via relay DC$dc: OK (${elapsed.elapsedMilliseconds} ms)',
      );
    }
    await client.close();
    stdout.writeln(
      'Verified 5 DCs and clean close. No API credentials, database or account login.',
    );
  } catch (_) {
    stderr.writeln(
      'TDLib relay verification failed; sensitive details omitted.',
    );
    exitCode = 1;
  } finally {
    try {
      await client?.close();
    } catch (_) {
      stderr.writeln('Native close failed; sensitive details omitted.');
      exitCode = 1;
    }
    await bridge?.close();
  }
}
