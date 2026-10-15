import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tg_cine/data/services/relay/public_relay_service.dart';
import 'package:tg_cine/domain/models/telegram_account.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = _LocalHttp();
  const storage = FlutterSecureStorage();
  final id = '11111111-1111-4111-8111-111111111111';
  final access = 'a.$id.${'a' * 43}.${'b' * 43}';
  final refresh = 'r.$id.${'c' * 43}.${'d' * 43}';
  late HttpServer server;
  late PublicRelayService service;
  late Uri origin;
  late List<String> calls;
  var status = 200;
  var oversized = false;
  var foreign = false;
  var duplicate = false;
  var expired = false;
  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    calls = [];
    status = 200;
    oversized = foreign = duplicate = false;
    expired = false;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    origin = Uri.parse('http://127.0.0.1:${server.port}');
    server.listen((request) async {
      calls.add(request.uri.path);
      request.response.statusCode = status;
      if (status != 200) {
        request.response.write('{}');
      } else if (oversized) {
        request.response.write('x' * 32769);
      } else if (request.uri.path == '/v1/config') {
        expect(request.headers.value('Authorization'), isNull);
        final issued =
            DateTime.now().millisecondsSinceEpoch - (expired ? 7200000 : 0);
        request.response.write(
          jsonEncode({
            'protocolVersion': 1,
            'relay': foreign
                ? 'wss://other.example/v1/tunnel'
                : 'ws://127.0.0.1:${server.port}/v1/tunnel',
            'targetPolicy': {
              'kind': 'telegram-cidr',
              'port': 443,
              'cidrs': duplicate
                  ? ['invalid']
                  : [
                      '149.154.160.0/20',
                      '91.108.56.0/22',
                      '2001:b28:f23f::/48',
                    ],
              'updatedAt': issued,
              'expiresAt': issued + 3600000,
            },
          }),
        );
      } else {
        expect(request.method, 'POST');
        expect(await utf8.decoder.bind(request).join(), '{}');
        if (request.uri.path != '/v1/devices') {
          expect(request.headers.value('Authorization'), 'Bearer $refresh');
        }
        if (request.uri.path == '/v1/devices/revoke') {
          request.response.statusCode = 204;
        } else {
          request.response.statusCode = request.uri.path == '/v1/devices'
              ? 201
              : 200;
          request.response.write(
            jsonEncode({
              'accessToken': access,
              if (request.uri.path == '/v1/devices') 'refreshToken': refresh,
              'expiresAt': DateTime.now()
                  .add(const Duration(minutes: 10))
                  .millisecondsSinceEpoch,
            }),
          );
        }
      }
      await request.response.close();
    });
    service = PublicRelayService(storage, origin: origin);
  });
  tearDown(() async {
    service.close();
    await server.close(force: true);
  });
  test('default configuration and concurrent enrollment keep only refresh in the vault', () async {
    final config = await service.configuration();
    expect(config.policy.targetFor('149.154.175.50', 443), 'ip4_959aaf32');
    expect(
      await Future.wait(List.generate(6, (_) => service.accessToken())),
      everyElement(access),
    );
    expect(calls, ['/v1/config', '/v1/devices']);
    expect(await storage.readAll(), {service.credentialKey: refresh});
  });
  test('reopening refreshes the installation, explicit revoke clears its credential', () async {
    await service.accessToken();
    service.close();
    service = PublicRelayService(storage, origin: origin);
    expect(await service.accessToken(), access);
    expect(calls, ['/v1/devices', '/v1/devices/refresh']);
    await service.revoke();
    expect(await storage.readAll(), isEmpty);
    expect(calls.last, '/v1/devices/revoke');
  });
  test(
    'resolves rotating targets from cached policy and rejects expiry',
    () async {
      await service.configuration();
      expect(await service.targetFor('91.108.56.139', 443), 'ip4_5b6c388b');
      expect(await service.targetFor('91.108.56.164', 443), 'ip4_5b6c38a4');
      expect(await service.targetFor('8.8.8.8', 443), isNull);
      expect(calls, ['/v1/config']);
      expired = true;
      await expectLater(
        service.configuration(),
        throwsA(isA<TelegramException>()),
      );
    },
  );
  test(
    'a rejected stored credential is not silently replaced by a new enrollment',
    () async {
      await storage.write(key: service.credentialKey, value: refresh);
      status = 401;
      await expectLater(
        service.accessToken(),
        throwsA(
          isA<TelegramException>().having(
            (e) => e.failure,
            'failure',
            TelegramFailure.authentication,
          ),
        ),
      );
      expect(calls, ['/v1/devices/refresh']);
      expect(await storage.read(key: service.credentialKey), refresh);
    },
  );
  test('service limits, redirects, oversized replies and conflicting targets fail closed', () async {
    status = 429;
    await expectLater(
      service.configuration(),
      throwsA(
        isA<TelegramException>().having(
          (e) => e.failure,
          'failure',
          TelegramFailure.serviceLimited,
        ),
      ),
    );
    status = 302;
    await expectLater(
      service.configuration(),
      throwsA(isA<TelegramException>()),
    );
    status = 200;
    oversized = true;
    await expectLater(
      service.configuration(),
      throwsA(isA<TelegramException>()),
    );
    oversized = false;
    foreign = true;
    await expectLater(
      service.configuration(),
      throwsA(isA<TelegramException>()),
    );
    foreign = false;
    duplicate = true;
    await expectLater(
      service.configuration(),
      throwsA(isA<TelegramException>()),
    );
    expect(await storage.readAll(), isEmpty);
  });
}

class _LocalHttp extends HttpOverrides {}
