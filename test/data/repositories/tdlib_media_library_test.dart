import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:tg_cine/data/repositories/sqlite_media_repository.dart';
import 'package:tg_cine/data/repositories/tdlib_telegram_repository.dart';
import 'package:tg_cine/domain/models/telegram_account.dart';

import '../services/telegram/telegram_history_service_test.dart'
    show historyVideo;

void main() {
  late Directory directory;
  late TdlibTelegramRepository repository;
  late SqliteMediaRepository store;
  late StreamController<Map<String, dynamic>> events;
  late List<Map<String, dynamic>> requests;
  late List<Map<String, dynamic>> pages;
  Completer<Map<String, dynamic>>? pending;
  Completer<void>? requested;
  Map<String, dynamic>? message;
  Completer<Map<String, dynamic>>? pendingMessage;
  var canGetLink = true;
  var account = 100;
  setUp(() async {
    account = 100;
    pending = null;
    requested = null;
    message = null;
    pendingMessage = null;
    canGetLink = true;
    directory = await Directory.systemTemp.createTemp('tg-cine-import-test-');
    events = StreamController.broadcast();
    requests = [];
    pages = [];
    repository = TdlibTelegramRepository(() async {
      store = SqliteMediaRepository.open(
        p.join(directory.path, 'media.db'),
        List.filled(32, 42),
      );
      if ((await store.readSources(account)).isEmpty) {
        await store.saveSources(account, {-1});
      }
      final current = store;
      return TelegramConnection(
        media: current,
        events: events.stream,
        readSources: current.readSources,
        writeSources: current.saveSources,
        close: current.close,
        request: (request) async {
          requests.add(request);
          return switch (request['@type']) {
            'getAuthorizationState' => {'@type': 'authorizationStateReady'},
            'getMe' => {'@type': 'user', 'id': account},
            'getChat' => {'@type': 'chat', 'title': 'design-source'},
            'getChats' => {
              '@type': 'chats',
              'chat_ids': [-1],
            },
            'searchChatMessages' => await (() async {
              requested?.complete();
              return pending?.future ?? Future.value(pages.removeAt(0));
            })(),
            'getMessageLink' => {
              '@type': 'messageLink',
              'link': 'https://t.me/c/123456/10',
            },
            'getMessage' =>
              await (pendingMessage?.future ??
                  Future.value(
                    message ?? historyVideo(request['message_id'] as int),
                  )),
            'getMessageProperties' => {
              '@type': 'messageProperties',
              'can_get_link': canGetLink,
            },
            _ => {'@type': 'ok'},
          };
        },
      );
    });
    await repository.connect();
  });
  tearDown(() async {
    await repository.close();
    await events.close();
    final path = await directory.resolveSymbolicLinks();
    final temp = await Directory.systemTemp.resolveSymbolicLinks();
    if (p.dirname(path) != temp ||
        !p.basename(path).startsWith('tg-cine-import-test-')) {
      throw StateError('Unexpected test directory');
    }
    await directory.delete(recursive: true);
  });
  Map<String, dynamic> page(List<Map<String, dynamic>> messages, int next) => {
    '@type': 'foundChatMessages',
    'messages': messages,
    'next_from_message_id': next,
  };

  test('native repository imports short pages transactionally, deduplicates and restores encrypted checkpoint', () async {
    pages.addAll([
      page([historyVideo(20)], 19),
      page([historyVideo(20), historyVideo(10, document: true)], 0),
    ]);
    await repository.importNext(-1);
    expect((await store.checkpoint(100, -1)).complete, isFalse);
    await repository.importNext(-1);
    expect(await repository.media(), hasLength(2));
    expect((await repository.imports()).single.imported, 2);
    expect(
      requests
          .where((r) => r['@type'] == 'searchChatMessages')
          .last['from_message_id'],
      19,
    );
    expect(requests.any((r) => r['@type'] == 'downloadFile'), isFalse);
    final media = (await repository.media()).first;
    expect(await repository.messageLink(media), startsWith('https://t.me/'));
    await repository.connect();
    expect((await repository.imports()).single.checkpoint.complete, isTrue);
    expect(await repository.media(query: 'design-source'), hasLength(2));
  });
  test(
    'persistent pause invalidates a pending response before commit',
    () async {
      pending = Completer();
      requested = Completer();
      final importing = repository.importNext(-1);
      await requested!.future;
      await repository.pauseImport(-1, true);
      final rejected = expectLater(
        importing,
        throwsA(isA<TelegramException>()),
      );
      pending!.complete(page([historyVideo(10)], 0));
      await rejected;
      expect(await repository.media(), isEmpty);
      expect((await store.checkpoint(100, -1)).paused, isTrue);
    },
  );
  test('deselection and changed account discard old responses and reject source link access', () async {
    pending = Completer();
    requested = Completer();
    final importing = repository.importNext(-1);
    await requested!.future;
    await repository.saveSources({});
    final rejected = expectLater(importing, throwsA(isA<TelegramException>()));
    pending!.complete(page([historyVideo(10)], 0));
    await rejected;
    expect(await store.loadVersions(100, -1, 10), isEmpty);
    pending = Completer();
    requested = Completer();
    await store.saveSources(100, {-1});
    await repository.connect();
    final oldAccountImport = repository.importNext(-1);
    await requested!.future;
    account = 200;
    await repository.connect();
    final oldRejected = expectLater(
      oldAccountImport,
      throwsA(isA<TelegramException>()),
    );
    pending!.complete(page([historyVideo(10)], 0));
    await oldRejected;
    expect(await repository.media(), isEmpty);
    expect(await store.loadVersions(100, -1, 10), isEmpty);
  });
  test('malformed pages retain checkpoint and message-link requests require a stored version', () async {
    pages.add(page([historyVideo(10, unique: '')], 0));
    await expectLater(
      repository.importNext(-1),
      throwsA(isA<TelegramException>()),
    );
    expect((await store.checkpoint(100, -1)).revision, 0);
    expect(await repository.media(), isEmpty);
    pages.add(page([historyVideo(10)], 0));
    await repository.importNext(-1);
    final item = (await repository.media()).single;
    await repository.saveSources({});
    await expectLater(
      repository.messageLink(item),
      throwsA(isA<TelegramException>()),
    );
    expect(requests.where((r) => r['@type'] == 'getMessageLink'), isEmpty);
  });
  test('unsupported message links return a capability failure without requesting a link', () async {
    pages.add(page([historyVideo(10)], 0));
    await repository.importNext(-1);
    canGetLink = false;
    await expectLater(
      repository.messageLink((await repository.media()).single),
      throwsA(
        isA<TelegramException>().having(
          (e) => e.failure,
          'failure',
          TelegramFailure.linkUnsupported,
        ),
      ),
    );
    expect(requests.where((r) => r['@type'] == 'getMessageLink'), isEmpty);
  });
  test('source links reload the original message after reopening without downloading media', () async {
    pages.add(page([historyVideo(10)], 0));
    await repository.importNext(-1);
    await repository.connect();
    requests.clear();
    final item = (await repository.media()).single;
    expect(await repository.messageLink(item), startsWith('https://t.me/'));
    final types = requests.map((r) => r['@type']).toList();
    expect(
      types.indexOf('getMessage'),
      lessThan(types.indexOf('getMessageLink')),
    );
    expect(
      requests.firstWhere((r) => r['@type'] == 'getMessage')['message_id'],
      item.messageId,
    );
    expect(types, isNot(contains('downloadFile')));
  });
  test(
    'deleted, foreign and replaced source messages cannot produce a link',
    () async {
      pages.add(page([historyVideo(10)], 0));
      await repository.importNext(-1);
      final item = (await repository.media()).single;
      for (final response in [
        {'@type': 'error'},
        historyVideo(10, source: -2),
        historyVideo(20),
        historyVideo(10, unique: 'replacement'),
      ]) {
        message = response;
        await expectLater(
          repository.messageLink(item),
          throwsA(isA<TelegramException>()),
        );
      }
      expect(requests.where((r) => r['@type'] == 'getMessageLink'), isEmpty);
    },
  );
  test('deselecting a source while loading its message rejects the late link request', () async {
    pages.add(page([historyVideo(10)], 0));
    await repository.importNext(-1);
    final item = (await repository.media()).single;
    pendingMessage = Completer();
    final linking = repository.messageLink(item);
    final rejected = expectLater(linking, throwsA(isA<TelegramException>()));
    while (!requests.any((r) => r['@type'] == 'getMessage')) {
      await Future<void>.delayed(Duration.zero);
    }
    await repository.saveSources({});
    pendingMessage!.complete(historyVideo(10));
    await rejected;
    expect(requests.where((r) => r['@type'] == 'getMessageLink'), isEmpty);
  });
}
