import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tg_cine/data/repositories/tdlib_telegram_repository.dart';
import 'package:tg_cine/domain/models/telegram_account.dart';

void main() {
  test(
    'reconnect completes an interrupted logout before reopening once',
    () async {
      final finished = Completer<void>();
      final waiting = Completer<void>();
      var opens = 0;
      var closes = 0;
      final repository = TdlibTelegramRepository(() async {
        final first = ++opens == 1;
        return TelegramConnection(
          request: (_) async => {
            '@type': first
                ? 'authorizationStateLoggingOut'
                : 'authorizationStateWaitPhoneNumber',
          },
          events: const Stream.empty(),
          readSources: (_) async => {},
          writeSources: (_, _) async {},
          close: () async {
            closes++;
          },
          waitForLogout: () {
            waiting.complete();
            return finished.future;
          },
        );
      }, defaultService: true);
      final connecting = repository.connect();
      await waiting.future;
      expect(repository.account.stage, TelegramStage.connecting);
      expect(opens, 1);
      expect(closes, 0);
      finished.complete();
      await connecting;
      expect(opens, 2);
      expect(closes, 1);
      expect(repository.account.stage, TelegramStage.phone);
      await repository.close();
    },
  );

  test(
    'logout waits for Telegram closure before revoking relay access',
    () async {
      final finished = Completer<void>();
      final waiting = Completer<void>();
      final order = <String>[];
      final repository = TdlibTelegramRepository(
        () async => TelegramConnection(
          request: (value) async {
            if (value['@type'] == 'getMe') return {'@type': 'user', 'id': 100};
            if (value['@type'] == 'logOut') {
              order.add('logOut');
              return {'@type': 'ok'};
            }
            return {'@type': 'authorizationStateReady'};
          },
          events: const Stream.empty(),
          readSources: (_) async => {},
          writeSources: (_, _) async {},
          close: () async {
            order.add('close');
          },
          waitForLogout: () {
            waiting.complete();
            return finished.future;
          },
          revokeRelay: () async {
            order.add('revoke');
          },
        ),
        defaultService: true,
      );
      await repository.connect();
      final logout = repository.logout();
      await waiting.future;
      expect(order, ['logOut']);
      finished.complete();
      await logout;
      expect(order, ['logOut', 'revoke', 'close']);
      await repository.close();
    },
  );
  test('default service status is independent of Telegram login and explicit retry resets rejected access', () async {
    var reset = 0;
    var opens = 0;
    var closed = 0;
    var revoked = 0;
    final repository = TdlibTelegramRepository(
      () async {
        if (++opens == 1) {
          throw const TelegramException(TelegramFailure.authentication);
        }
        return TelegramConnection(
          request: (_) async => {'@type': 'authorizationStateWaitPhoneNumber'},
          events: const Stream.empty(),
          readSources: (_) async => {},
          writeSources: (_, _) async {},
          close: () async {
            closed++;
          },
          revokeRelay: () async {
            revoked++;
          },
        );
      },
      defaultService: true,
      resetDefaultAccess: () async {
        reset++;
      },
    );
    await expectLater(repository.connect(), throwsA(isA<TelegramException>()));
    expect(repository.account.defaultService, isTrue);
    expect(repository.account.relayReady, isFalse);
    expect(reset, 0);
    await repository.connect();
    expect(reset, 1);
    expect(repository.account.stage, TelegramStage.phone);
    expect(repository.account.relayReady, isTrue);
    await repository.close();
    expect(closed, 1);
    expect(revoked, 0);
  });
  test(
    'explicit logout closes the connection even when relay revocation fails',
    () async {
      var closed = 0;
      final repository = TdlibTelegramRepository(
        () async => TelegramConnection(
          request: (_) async => {'@type': 'authorizationStateWaitPhoneNumber'},
          events: const Stream.empty(),
          readSources: (_) async => {},
          writeSources: (_, _) async {},
          close: () async {
            closed++;
          },
          revokeRelay: () async =>
              throw const TelegramException(TelegramFailure.connection),
        ),
        defaultService: true,
      );
      await repository.connect();
      await expectLater(repository.logout(), throwsA(isA<TelegramException>()));
      expect(repository.account.stage, TelegramStage.disconnected);
      expect(repository.account.relayReady, isFalse);
      expect(closed, 1);
      await repository.close();
    },
  );
}
