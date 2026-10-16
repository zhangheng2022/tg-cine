import 'dart:async';
import 'dart:io';
import 'dart:convert';

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
            'getFileDownloadedPrefixSize' => {
              'size': requests.any((r) => r['@type'] == 'downloadFile')
                  ? 1024
                  : 0,
            },
            'readFilePart' => {
              'data': base64Encode(
                List.generate(
                  request['count'] as int,
                  (i) => ((request['offset'] as int) + i) % 256,
                ),
              ),
            },
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

  test(
    'an empty first update page still establishes the later high-water mark',
    () async {
      pages.add(page([historyVideo(20)], 0));
      await repository.importNext(-1);
      pages.add(page([], 50));
      expect(await repository.updateNext(-1), isFalse);
      pages.add(page([historyVideo(40)], 30));
      expect(await repository.updateNext(-1), isFalse);
      pages.add(page([historyVideo(20)], 0));
      expect(await repository.updateNext(-1), isTrue);
      expect((await store.updateCheckpoint(100, -1)).highWater, 40);
    },
  );

  test('new-message updates resume from their own cursor and never advance history', () async {
    pages.add(page([historyVideo(20), historyVideo(10)], 9));
    await repository.importNext(-1);
    final original = (await store.loadMedia(100)).first;
    await store.saveProgress(
      100,
      original.versionKey,
      const Duration(seconds: 4),
    );
    pages.add(page([historyVideo(50), historyVideo(40)], 39));
    expect(await repository.updateNext(-1), isFalse);
    expect((await store.checkpoint(100, -1)).nextMessageId, 9);
    expect((await store.updateCheckpoint(100, -1)).cursor, 39);
    await repository.pauseImport(-1, true);
    await expectLater(
      repository.updateNext(-1),
      throwsA(isA<TelegramException>()),
    );
    await repository.pauseImport(-1, false);
    pages.add(page([historyVideo(30), historyVideo(20)], 19));
    expect(await repository.updateNext(-1), isTrue);
    expect(
      requests
          .where((r) => r['@type'] == 'searchChatMessages')
          .last['from_message_id'],
      39,
    );
    expect((await store.updateCheckpoint(100, -1)).highWater, 50);
    expect((await store.checkpoint(100, -1)).nextMessageId, 9);
    expect(await store.loadMedia(100), hasLength(5));
    expect(
      await store.loadProgress(100, original.versionKey),
      const Duration(seconds: 4),
    );
    pages.add(page([historyVideo(50), historyVideo(40)], 39));
    expect(await repository.updateNext(-1), isTrue);
    expect(await store.loadMedia(100), hasLength(5));
    pages.add(page([historyVideo(8)], 0));
    await repository.importNext(-1);
    expect(await store.loadMedia(100), hasLength(6));
    expect((await store.updateCheckpoint(100, -1)).highWater, 50);
  });

  test('failed update and deselection do not commit fetched pages', () async {
    pages.add(page([historyVideo(20)], 0));
    await repository.importNext(-1);
    pages.add({'@type': 'error'});
    await expectLater(
      repository.updateNext(-1),
      throwsA(isA<TelegramException>()),
    );
    expect((await store.updateCheckpoint(100, -1)).highWater, 20);
    requested = Completer<void>();
    pending = Completer<Map<String, dynamic>>();
    final operation = repository.updateNext(-1);
    await requested!.future;
    await repository.saveSources({});
    pending!.complete(page([historyVideo(30)], 0));
    await expectLater(operation, throwsA(isA<TelegramException>()));
    expect((await store.updateCheckpoint(100, -1)).highWater, 20);
  });

  test('playback serves exact ranges and restores progress scoped to the file version', () async {
    pages.add(page([historyVideo(10)], 0));
    await repository.importNext(-1);
    final item = (await repository.media()).single;
    await store.saveProgress(100, item.versionKey, const Duration(seconds: 4));
    final source = await repository.openPlayback(item);
    expect(source.position, const Duration(seconds: 4));
    final client = HttpClient();
    addTearDown(() => client.close(force: true));
    final request = await client.getUrl(source.uri);
    request.headers.set(HttpHeaders.rangeHeader, 'bytes=5-16');
    final response = await request.close();
    expect(response.statusCode, 206);
    expect(
      response.headers.value(HttpHeaders.contentRangeHeader),
      'bytes 5-16/1024',
    );
    final bytes = await response.fold<List<int>>(
      [],
      (all, part) => all..addAll(part),
    );
    expect(bytes, List.generate(12, (i) => i + 5));
    await source.savePosition(const Duration(seconds: 7));
    expect(
      await store.loadProgress(100, item.versionKey),
      const Duration(seconds: 7),
    );
    final uri = source.uri;
    await repository.saveSources({});
    await source.closed;
    await source.close();
    expect(requests.any((r) => r['@type'] == 'cancelDownloadFile'), isTrue);
    await expectLater(source.savePosition(Duration.zero), throwsStateError);
    await expectLater(
      client.getUrl(uri).then((request) => request.close()),
      throwsA(isA<IOException>()),
    );
  });

  test('replacement and logout close previous media without sharing account progress', () async {
    pages.add(page([historyVideo(10)], 0));
    await repository.importNext(-1);
    final item = (await repository.media()).single;
    final first = await repository.openPlayback(item);
    final second = await repository.openPlayback(item);
    await first.closed;
    await expectLater(first.savePosition(Duration.zero), throwsStateError);
    await repository.logout();
    await second.closed;
    account = 200;
    await repository.connect();
    expect(await store.loadProgress(200, item.versionKey), isNull);
    await expectLater(
      repository.openPlayback(item),
      throwsA(isA<TelegramException>()),
    );
  });

  test('playback refuses changed, ephemeral and deselected messages', () async {
    pages.add(page([historyVideo(10)], 0));
    await repository.importNext(-1);
    final item = (await repository.media()).single;
    message = historyVideo(10, unique: 'replaced');
    await expectLater(
      repository.openPlayback(item),
      throwsA(isA<TelegramException>()),
    );
    message = historyVideo(
      10,
    )..['self_destruct_type'] = {'@type': 'messageSelfDestructTypeImmediately'};
    await expectLater(
      repository.openPlayback(item),
      throwsA(isA<TelegramException>()),
    );
    message = null;
    await repository.saveSources({});
    await expectLater(
      repository.openPlayback(item),
      throwsA(isA<TelegramException>()),
    );
    expect(requests.any((r) => r['@type'] == 'downloadFile'), isFalse);
  });

  test('a pending open cannot survive account replacement', () async {
    pages.add(page([historyVideo(10)], 0));
    await repository.importNext(-1);
    final item = (await repository.media()).single;
    pendingMessage = Completer();
    final opening = repository.openPlayback(item);
    final rejected = expectLater(opening, throwsA(isA<TelegramException>()));
    await Future<void>.delayed(Duration.zero);
    account = 200;
    await repository.connect();
    pendingMessage!.complete(historyVideo(10));
    await rejected;
    expect(requests.any((r) => r['@type'] == 'downloadFile'), isFalse);
  });

  test('concurrent opens admit only the most recent selection', () async {
    pages.add(page([historyVideo(10)], 0));
    await repository.importNext(-1);
    final item = (await repository.media()).single;
    pendingMessage = Completer();
    final first = repository.openPlayback(item);
    final rejected = expectLater(first, throwsA(isA<TelegramException>()));
    await Future<void>.delayed(Duration.zero);
    final second = repository.openPlayback(item);
    await Future<void>.delayed(Duration.zero);
    pendingMessage!.complete(historyVideo(10));
    await rejected;
    await (await second).close();
  });

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
