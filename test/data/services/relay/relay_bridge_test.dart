import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tg_cine/data/services/relay/relay_bridge.dart';
import 'package:tg_cine/data/services/relay/telegram_target_policy.dart';

void main() {
  for (final mode in [0, 1, 2]) {
    final renewable = mode > 0;
    test(
      'loopback SOCKS bridge relays binary data and rejects other destinations (mode: $mode)',
      () async {
        final service = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        final peers = <WebSocket>[];
        final paths = <Uri>[];
        final server = service.listen((request) async {
          expect(request.headers.value('Authorization'), 'Bearer test-token');
          paths.add(request.uri);
          final socket = await WebSocketTransformer.upgrade(request);
          peers.add(socket);
          socket.listen((frame) {
            if (frame is List<int>) {
              socket.add('ACK');
              socket.add(frame);
            } else {
              expect(frame, 'ACK');
            }
          });
        });
        final now = DateTime.now().millisecondsSinceEpoch;
        final policy = TelegramTargetPolicy.parse({
          'kind': 'telegram-cidr',
          'port': 443,
          'cidrs': ['149.154.160.0/20'],
          'updatedAt': now,
          'expiresAt': now + 3600000,
        });
        final bridge = await RelayBridge.start(
          relay: Uri.parse('ws://127.0.0.1:${service.port}/v2/tunnel'),
          token: renewable ? '' : 'test-token',
          accessToken: renewable ? () async => 'test-token' : null,
          targets: mode == 2 ? {} : {('149.154.167.51', 443): 'dc2'},
          resolveTarget: mode == 2
              ? (host, port) async => policy.targetFor(host, port)
              : null,
        );
        addTearDown(() async {
          await bridge.close();
          await Future.wait(peers.map((socket) => socket.close()));
          await server.cancel();
          await service.close(force: true);
        });

        final client = await Socket.connect(
          InternetAddress.loopbackIPv4,
          bridge.port,
        );
        final data = StreamIterator(client);
        // Deliberately split the handshake to exercise TCP fragmentation.
        client.add([5]);
        await client.flush();
        client.add([1, 0]);
        expect(await data.moveNext(), isTrue);
        expect(data.current, [5, 0]);
        client.add([5, 1, 0, 1, 149, 154, 167, 51, 1, 187]);
        expect(await data.moveNext(), isTrue);
        expect(data.current[1], 0);
        final payload = Uint8List.fromList(
          List.generate(130000, (index) => index % 256),
        );
        client.add(payload);
        final echoed = <int>[];
        while (echoed.length < payload.length && await data.moveNext()) {
          echoed.addAll(data.current);
        }
        expect(echoed, payload);
        final target = mode == 2 ? 'ip4_959aa733' : 'dc2';
        expect(bridge.traffic[target]!['uploadedBytes'], payload.length);
        expect(bridge.traffic[target]!['downloadedBytes'], payload.length);
        expect(bridge.traffic[target]!['downFrames'], greaterThan(0));
        expect(bridge.traffic[target]!['downWriteUs'], greaterThanOrEqualTo(0));
        expect(bridge.traffic[target]!['upAckCount'], greaterThan(0));
        expect(bridge.traffic[target]!['maxUpAckUs'], greaterThan(0));
        expect(bridge.capacityRejections, 0);
        expect(paths.single.path, '/v2/tunnel');
        expect(paths.single.queryParameters, {'v': '2', 'target': target});
        expect(paths.single.toString(), isNot(contains('test-token')));
        client.destroy();
        await data.cancel();

        final denied = await Socket.connect(
          InternetAddress.loopbackIPv4,
          bridge.port,
        );
        final rejected = StreamIterator(denied);
        denied.add([5, 1, 0]);
        await rejected.moveNext();
        denied.add([5, 1, 0, 1, 127, 0, 0, 1, 0, 80]);
        expect(await rejected.moveNext(), isTrue);
        expect(rejected.current[1], 2);
        expect(bridge.lastRejectedTarget, ('127.0.0.1', 80));
        expect(paths, hasLength(1));
        denied.destroy();
        await rejected.cancel();
      },
      timeout: const Timeout(Duration(seconds: 15)),
    );
  }

  test(
    'configuration rejects remote cleartext and credentials in URL',
    () async {
      for (final endpoint in [
        'ws://remote.example/v2/tunnel',
        'wss://token@host/v2/tunnel',
        'wss://host/v2/tunnel?token=x',
      ]) {
        await expectLater(
          RelayBridge.start(
            relay: Uri.parse(endpoint),
            token: 'token',
            targets: {('host', 443): 'dc2'},
          ),
          throwsArgumentError,
        );
      }
    },
  );
}
