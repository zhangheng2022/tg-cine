import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:tg_cine/data/services/relay/relay_bridge.dart';

/// Runs against the ephemeral workerd/TCP server started by worker's test:relay.
Future<void> main(List<String> arguments) async {
  final workerPort = int.parse(arguments[0]);
  final echoPort = int.parse(arguments[1]);
  final token = (await File(arguments[2]).readAsString()).trim();
  final bridge = await RelayBridge.start(
    relay: Uri.parse('ws://127.0.0.1:$workerPort/v2/tunnel'),
    token: token,
    targets: {('127.0.0.1', echoPort): 'local_echo'},
  );
  Socket? socket;
  StreamIterator<Uint8List>? input;
  try {
    socket = await Socket.connect(InternetAddress.loopbackIPv4, bridge.port);
    input = StreamIterator(socket);
    socket.add([5, 1, 0]);
    if (!await input.moveNext().timeout(const Duration(seconds: 10)) ||
        input.current[1] != 0) {
      throw StateError('SOCKS negotiation failed');
    }
    socket.add([5, 1, 0, 1, 127, 0, 0, 1, echoPort >> 8, echoPort & 255]);
    if (!await input.moveNext().timeout(const Duration(seconds: 10)) ||
        input.current[1] != 0) {
      throw StateError('Relay connection failed');
    }
    final payload = Uint8List.fromList(
      List.generate(1048576, (index) => index % 251),
    );
    socket.add(payload);
    stdout.writeln('SOCKS5 and local Worker connected; transferring 1 MiB.');
    var received = 0;
    while (received < payload.length &&
        await input.moveNext().timeout(const Duration(seconds: 10))) {
      for (final byte in input.current) {
        if (received >= payload.length || byte != payload[received++]) {
          throw StateError('Relay changed byte order or content');
        }
      }
    }
    if (received != payload.length) {
      throw StateError('Incomplete relay response');
    }
    stdout.writeln(
      'Verified $received ordered bytes: Dart SOCKS5 → workerd WebSocket → TCP echo → Dart.',
    );
  } finally {
    socket?.destroy();
    await input?.cancel();
    stdout.writeln('Local test socket closed.');
    await bridge.close();
    stdout.writeln('Bridge resources closed.');
  }
}
