import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tg_cine/data/repositories/tdlib_telegram_repository.dart';
import 'package:tg_cine/data/services/telegram/tdlib_probe.dart';
import 'package:tg_cine/domain/models/telegram_account.dart';

void main() {
  late StreamController<Map<String, dynamic>> updates;
  late TdlibTelegramRepository repository;
  late List<Map<String, dynamic>> calls;
  late Map<int, Set<int>> persisted;
  var state = 'authorizationStateWaitPhoneNumber';
  var accountId = 100;
  var failAuthentication = false;
  var failStorage = false;
  var closed = 0;

  setUp(() {
    updates = StreamController.broadcast(sync: true);
    calls = [];
    persisted = {};
    state = 'authorizationStateWaitPhoneNumber';
    accountId = 100;
    failAuthentication = false;
    failStorage = false;
    closed = 0;
    repository = TdlibTelegramRepository(
      () async => TelegramConnection(
        events: updates.stream,
        readSources: (id) async => Set.of(persisted[id] ?? {}),
        writeSources: (id, ids) async {
          if (failStorage) throw StateError('private local path');
          persisted[id] = Set.of(ids);
        },
        close: () async {
          closed++;
        },
        request: (command) async {
          calls.add(command);
          switch (command['@type']) {
            case 'getAuthorizationState':
              return {'@type': state};
            case 'getMe':
              return {'@type': 'user', 'id': accountId};
            case 'setAuthenticationPhoneNumber':
            case 'checkAuthenticationCode':
            case 'checkAuthenticationPassword':
              if (failAuthentication) throw const TdlibRequestError(400);
              state = switch (command['@type']) {
                'setAuthenticationPhoneNumber' => 'authorizationStateWaitCode',
                'checkAuthenticationCode' => 'authorizationStateWaitPassword',
                _ => 'authorizationStateReady',
              };
              updates.add({
                '@type': 'updateAuthorizationState',
                'authorization_state': {'@type': state},
              });
              return {'@type': 'ok'};
            case 'loadChats':
              throw const TdlibRequestError(404);
            case 'getChats':
              return {
                '@type': 'chats',
                'chat_ids': command['chat_list']['@type'] == 'chatListMain'
                    ? [-1, 3]
                    : [-1, -2],
              };
            case 'getChat':
              return {
                '@type': 'chat',
                'id': command['chat_id'],
                'title': 'Local test ${command['chat_id']}',
                'type': {'@type': 'chatTypePrivate'},
              };
            case 'logOut':
              state = 'authorizationStateClosed';
              return {'@type': 'ok'};
            default:
              throw StateError('Unexpected test request');
          }
        },
      ),
    );
  });
  tearDown(() async {
    await repository.close();
    await updates.close();
  });

  test(
    'missing native runtime is unavailable, not an authentication failure',
    () async {
      final unavailable = TdlibTelegramRepository(
        () async => throw const TelegramException(TelegramFailure.unavailable),
      );
      await expectLater(
        unavailable.connect(),
        throwsA(
          isA<TelegramException>().having(
            (e) => e.failure,
            'failure',
            TelegramFailure.unavailable,
          ),
        ),
      );
      expect(unavailable.account.stage, TelegramStage.failed);
      expect(unavailable.account.failure, TelegramFailure.unavailable);
      await unavailable.close();
    },
  );

  test('phone, code and password transition to verified account', () async {
    await repository.connect();
    expect(repository.account.stage, TelegramStage.phone);
    await repository.submit('+12345678901');
    expect(repository.account.stage, TelegramStage.code);
    await repository.submit('12345');
    expect(repository.account.stage, TelegramStage.password);
    await repository.submit('test-only-password');
    expect(repository.account.id, 100);
    expect(calls.where((c) => c['@type'] == 'getMe'), hasLength(1));
  });

  test('invalid input never reaches native authentication', () async {
    await repository.connect();
    final before = calls.length;
    await expectLater(
      repository.submit('invalid'),
      throwsA(isA<TelegramException>()),
    );
    expect(calls.length, before);
  });

  test(
    'authentication failure preserves login stage and omits native details',
    () async {
      await repository.connect();
      failAuthentication = true;
      await expectLater(
        repository.submit('+12345678901'),
        throwsA(
          isA<TelegramException>().having(
            (e) => e.failure,
            'failure',
            TelegramFailure.authentication,
          ),
        ),
      );
      expect(repository.account.stage, TelegramStage.phone);
    },
  );

  test('restores account-scoped selection; loads main and archive without type filtering', () async {
    state = 'authorizationStateReady';
    persisted[100] = {-2};
    await repository.connect();
    expect(repository.account.selectedSources, {-2});
    final page = await repository.loadSources();
    expect(page.sources.map((s) => s.id).toSet(), {-1, -2, 3});
    expect(page.hasMore, isFalse);
    expect(calls.where((c) => c['@type'] == 'getChat'), hasLength(3));
    await repository.saveSources({-1, 3});
    expect(persisted[100], {-1, 3});
    await repository.connect();
    expect(repository.account.selectedSources, {-1, 3});
    expect(closed, 1);
    accountId = 200;
    await repository.connect();
    expect(repository.account.selectedSources, isEmpty);
  });

  test(
    'storage failure retains committed selection and rejects unknown source',
    () async {
      state = 'authorizationStateReady';
      persisted[100] = {-1};
      await repository.connect();
      await repository.loadSources();
      await expectLater(
        repository.saveSources({-999}),
        throwsA(isA<TelegramException>()),
      );
      failStorage = true;
      await expectLater(
        repository.saveSources({-2}),
        throwsA(
          isA<TelegramException>().having(
            (e) => e.failure,
            'failure',
            TelegramFailure.storage,
          ),
        ),
      );
      expect(repository.account.selectedSources, {-1});
      expect(persisted[100], {-1});
    },
  );

  test(
    'logout revokes authorization; ordinary close does not send logout',
    () async {
      state = 'authorizationStateReady';
      await repository.connect();
      await repository.logout();
      expect(repository.account.stage, TelegramStage.disconnected);
      expect(calls.where((c) => c['@type'] == 'logOut'), hasLength(1));
      await repository.close();
      expect(closed, 1);
    },
  );

  test(
    'close during opening closes returned client and ignores late state',
    () async {
      final opening = Completer<TelegramConnection>();
      final delayed = TdlibTelegramRepository(() => opening.future);
      final connection = repository.connect();
      await connection;
      final connect = delayed.connect();
      final closing = delayed.close();
      opening.complete(
        TelegramConnection(
          request: (_) async => {'@type': 'authorizationStateReady'},
          events: updates.stream,
          readSources: (_) async => {},
          writeSources: (_, _) async {},
          close: () async {
            closed++;
          },
        ),
      );
      await connect;
      await closing;
      expect(delayed.account.stage, TelegramStage.connecting);
      expect(closed, 1);
    },
  );
}
