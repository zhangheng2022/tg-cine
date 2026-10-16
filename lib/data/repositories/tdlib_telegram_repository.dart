import '../../domain/models/media_organization.dart';
import '../../domain/models/watch_record.dart';

import 'dart:async';

import '../../domain/models/telegram_account.dart';
import '../../domain/ports/telegram_repository.dart';
import '../../domain/ports/media_playback_repository.dart';
import '../services/playback/telegram_playback_source.dart';
import '../services/playback/playback_trace.dart';
import '../../domain/ports/media_library_repository.dart';
import '../../domain/models/media_work.dart';
import '../../domain/ports/local_media_repository.dart';
import '../../domain/models/local_media.dart';
import '../services/telegram/telegram_history_service.dart';
import '../services/telegram/telegram_credentials.dart';
import '../services/telegram/tdlib_probe.dart';
import '../services/telegram/telegram_video_file.dart';

typedef TelegramRequest = Future<Map<String, dynamic>> Function(
  Map<String, dynamic>,
);

class TelegramConnection {
  const TelegramConnection({
    required this.request,
    required this.events,
    required this.readSources,
    required this.writeSources,
    required this.close,
    this.media,
    this.revokeRelay,
    this.waitForLogout,
  });

  final TelegramRequest request;
  final Stream<Map<String, dynamic>> events;
  final Future<Set<int>> Function(int accountId) readSources;
  final Future<void> Function(int accountId, Set<int> ids) writeSources;
  final Future<void> Function() close;
  final LocalMediaRepository? media;
  final Future<void> Function()? revokeRelay;
  final Future<void> Function()? waitForLogout;
}

typedef _LibraryScope = ({
  int generation,
  int accountId,
  TelegramConnection connection,
  LocalMediaRepository store,
});

class TdlibTelegramRepository
    implements
        TelegramRepository,
        MediaLibraryRepository,
        MediaPlaybackRepository {
  TdlibTelegramRepository(
    this._open, {
    this.defaultService = false,
    this.resetDefaultAccess,
    this.playbackTrace,
  }) {
    _account = TelegramAccount(
      stage: TelegramStage.disconnected,
      defaultService: defaultService,
    );
  }

  final Future<TelegramConnection> Function() _open;
  final bool defaultService;
  final PlaybackTrace? playbackTrace;
  final Future<void> Function()? resetDefaultAccess;
  final _accounts = StreamController<TelegramAccount>.broadcast(sync: true);
  TelegramAccount _account = TelegramAccount(stage: TelegramStage.disconnected);
  TelegramConnection? _connection;
  StreamSubscription<Map<String, dynamic>>? _subscription;
  Future<void> _authorization = Future.value();
  final _sources = <int, TelegramSource>{};
  final _exhausted = <String>{};
  int _limit = 0;
  int _generation = 0;
  PlaybackMedia? _playback;
  int? _playingSource;
  int _playbackGeneration = 0;
  bool _closed = false;
  bool _connecting = false;
  Future<void>? _opening;

  @override
  TelegramAccount get account => _account;
  @override
  Stream<TelegramAccount> get accounts => _accounts.stream;

  void _publish(TelegramAccount value) {
    if (_closed) return;
    if (value.stage != TelegramStage.ready ||
        value.id != _account.id ||
        (_playingSource != null &&
            !value.selectedSources.contains(_playingSource))) {
      unawaited(_closePlayback().catchError((Object _) {}));
    }
    _account = TelegramAccount(
      stage: value.stage,
      id: value.id,
      failure: value.failure,
      selectedSources: value.selectedSources,
      defaultService: defaultService,
      relayReady:
          defaultService &&
          _connection != null &&
          ![
            TelegramStage.connecting,
            TelegramStage.failed,
            TelegramStage.disconnected,
          ].contains(value.stage),
    );
    _accounts.add(_account);
  }

  @override
  Future<void> connect() {
    if (_closed || _connecting) return Future.value();
    return _opening = _connect();
  }

  Future<void> _connect() async {
    _connecting = true;
    final resetAccess =
        defaultService &&
        _account.stage == TelegramStage.failed &&
        _account.failure == TelegramFailure.authentication;
    final generation = ++_generation;
    _publish(TelegramAccount(stage: TelegramStage.connecting));
    try {
      await _disconnect();
      if (resetAccess) await resetDefaultAccess?.call();
      final connection = await _open();
      if (_closed || generation != _generation) {
        await connection.close();
        return;
      }
      _connection = connection;
      var state = await connection.request({'@type': 'getAuthorizationState'});
      if ([
        'authorizationStateLoggingOut',
        'authorizationStateClosing',
        'authorizationStateClosed',
      ].contains(state['@type'])) {
        // Keep relay access until Telegram finishes a previously interrupted logout.
        if (state['@type'] != 'authorizationStateClosed') {
          final wait = connection.waitForLogout;
          if (wait == null) {
            throw const TelegramException(TelegramFailure.connection);
          }
          await wait();
        }
        await _disconnect();
        if (_closed || generation != _generation) return;
        final reopened = await _open();
        if (_closed || generation != _generation) {
          await reopened.close();
          return;
        }
        _connection = reopened;
        state = await reopened.request({'@type': 'getAuthorizationState'});
        if ([
          'authorizationStateLoggingOut',
          'authorizationStateClosing',
          'authorizationStateClosed',
        ].contains(state['@type'])) {
          throw const TelegramException(TelegramFailure.connection);
        }
      }
      _subscription = _connection!.events.listen((event) {
        if (event['@type'] == 'updateAuthorizationState') {
          _enqueueAuthorization(
            event['authorization_state'] as Map<String, dynamic>,
            generation,
          );
        }
      });
      await _enqueueAuthorization(state, generation);
    } catch (error) {
      try {
        await _disconnect();
      } catch (_) {
        // Native close failures must not suppress the connection failure shown by the UI.
      }
      if (!_closed && generation == _generation) {
        _publish(
          TelegramAccount(
            stage: TelegramStage.failed,
            failure: error is TelegramException
                ? error.failure
                : TelegramFailure.connection,
          ),
        );
      }
      throw TelegramException(
        error is TelegramException ? error.failure : TelegramFailure.connection,
      );
    } finally {
      _connecting = false;
    }
  }

  Future<void> _enqueueAuthorization(
    Map<String, dynamic> state,
    int generation,
  ) {
    _authorization = _authorization
        .then((_) async {
          if (_closed || generation != _generation) return;
          final stage = switch (state['@type']) {
            'authorizationStateWaitPhoneNumber' => TelegramStage.phone,
            'authorizationStateWaitCode' => TelegramStage.code,
            'authorizationStateWaitPassword' => TelegramStage.password,
            'authorizationStateWaitEmailAddress' => TelegramStage.email,
            'authorizationStateWaitEmailCode' => TelegramStage.emailCode,
            'authorizationStateReady' => TelegramStage.ready,
            'authorizationStateClosing' ||
            'authorizationStateLoggingOut' => TelegramStage.connecting,
            'authorizationStateClosed' => TelegramStage.failed,
            'authorizationStateWaitTdlibParameters' => TelegramStage.connecting,
            _ => TelegramStage.unsupported,
          };
          if (stage == TelegramStage.ready) {
            if (_account.stage == TelegramStage.ready) return;
            final me = await _connection!.request({'@type': 'getMe'});
            if (me['@type'] != 'user' || me['id'] is! int) {
              throw const TelegramException(TelegramFailure.authentication);
            }
            final id = me['id'] as int;
            final Set<int> selected;
            try {
              selected = await _connection!.readSources(id);
            } catch (_) {
              throw const TelegramException(TelegramFailure.storage);
            }
            if (!_closed && generation == _generation) {
              _publish(
                TelegramAccount(
                  stage: stage,
                  id: id,
                  selectedSources: selected,
                ),
              );
            }
          } else {
            _sources.clear();
            _exhausted.clear();
            _limit = 0;
            _publish(
              TelegramAccount(
                stage: stage,
                failure: stage == TelegramStage.failed
                    ? TelegramFailure.connection
                    : null,
              ),
            );
          }
        })
        .catchError((Object error) {
          if (!_closed && generation == _generation) {
            _publish(
              TelegramAccount(
                stage: TelegramStage.failed,
                failure: error is TelegramException
                    ? error.failure
                    : TelegramFailure.connection,
              ),
            );
          }
        });
    return _authorization;
  }

  @override
  Future<void> submit(String input) async {
    final nativeState = switch (_account.stage) {
      TelegramStage.phone => 'authorizationStateWaitPhoneNumber',
      TelegramStage.code => 'authorizationStateWaitCode',
      TelegramStage.password => 'authorizationStateWaitPassword',
      TelegramStage.email => 'authorizationStateWaitEmailAddress',
      TelegramStage.emailCode => 'authorizationStateWaitEmailCode',
      _ => throw const TelegramException(TelegramFailure.authentication),
    };
    final Map<String, dynamic> command;
    try {
      command = loginRequest(nativeState, input);
    } on FormatException {
      throw const TelegramException(TelegramFailure.invalidInput);
    }
    try {
      await _connection!.request(command);
      await _authorization;
    } on TdlibRequestError {
      throw const TelegramException(TelegramFailure.authentication);
    } catch (_) {
      throw const TelegramException(TelegramFailure.connection);
    }
  }

  void _requireReady() {
    if (_closed ||
        _account.stage != TelegramStage.ready ||
        _connection == null) {
      throw const TelegramException(TelegramFailure.authentication);
    }
  }

  @override
  Future<TelegramSourcePage> loadSources() async {
    _requireReady();
    final generation = _generation;
    final id = _account.id;
    final connection = _connection!;
    _limit += 100;
    for (final list in ['chatListMain', 'chatListArchive']) {
      if (!_exhausted.contains(list)) {
        try {
          await connection.request({
            '@type': 'loadChats',
            'chat_list': {'@type': list},
            'limit': 100,
          });
        } on TdlibRequestError catch (error) {
          if (error.code != 404) rethrow;
          _exhausted.add(list);
        }
      }
      final response = await connection.request({
        '@type': 'getChats',
        'chat_list': {'@type': list},
        'limit': _limit,
      });
      for (final chatId in (response['chat_ids'] as List).cast<int>()) {
        if (!_sources.containsKey(chatId)) {
          final chat = await connection.request({
            '@type': 'getChat',
            'chat_id': chatId,
          });
          if (generation != _generation || _account.id != id) {
            throw const TelegramException(TelegramFailure.authentication);
          }
          _sources[chatId] = TelegramSource(
            id: chatId,
            title: chat['title'] as String,
          );
        }
      }
    }
    _requireReady();
    return TelegramSourcePage(
      sources: _sources.values.toList(),
      hasMore: _exhausted.length != 2,
    );
  }

  @override
  Future<void> saveSources(Set<int> sourceIds) async {
    _requireReady();
    if (sourceIds.length > 1000 ||
        sourceIds.any(
          (id) =>
              !_sources.containsKey(id) &&
              !_account.selectedSources.contains(id),
        )) {
      throw const TelegramException(TelegramFailure.invalidInput);
    }
    final accountId = _account.id!;
    try {
      await _connection!.writeSources(accountId, sourceIds);
    } catch (_) {
      throw const TelegramException(TelegramFailure.storage);
    }
    if (_account.id == accountId && !_closed) {
      _publish(
        TelegramAccount(
          stage: TelegramStage.ready,
          id: accountId,
          selectedSources: sourceIds,
        ),
      );
    }
  }

  void _checkLibrary(_LibraryScope scope, [int? sourceId]) {
    _requireReady();
    if (_generation != scope.generation ||
        !identical(_connection, scope.connection) ||
        _account.id != scope.accountId ||
        (sourceId != null && !_account.selectedSources.contains(sourceId))) {
      throw const TelegramException(TelegramFailure.authentication);
    }
  }

  Future<T> _library<T>(Future<T> Function(_LibraryScope) action) async {
    _requireReady();
    final store = _connection!.media;
    if (store == null) {
      throw const TelegramException(TelegramFailure.unavailable);
    }
    final scope = (
      generation: _generation,
      accountId: _account.id!,
      connection: _connection!,
      store: store,
    );
    try {
      final result = await action(scope);
      _checkLibrary(scope);
      return result;
    } on TelegramException {
      rethrow;
    } on LocalMediaException catch (error) {
      throw TelegramException(
        error.failure == LocalMediaFailure.conflict
            ? TelegramFailure.invalidInput
            : TelegramFailure.storage,
      );
    } catch (_) {
      throw const TelegramException(TelegramFailure.connection);
    }
  }

  @override
  Future<List<LocalMedia>> media({
    int offset = 0,
    int limit = 50,
    String query = '',
    MediaKind? kind,
  }) => _library(
    (scope) => scope.store.loadMedia(
      scope.accountId,
      offset: offset,
      limit: limit,
      query: query,
      kind: kind,
    ),
  );

  @override
  Future<void> saveOrganization(LocalMedia media, MediaOrganization? value) =>
      _library((scope) async {
        _checkLibrary(scope, media.sourceId);
        await scope.store.saveOrganization(
          scope.accountId,
          media.versionKey,
          value,
        );
      });

  @override
  Future<List<MediaWork>> works({
    String query = '',
    int offset = 0,
    int limit = 50,
  }) => _library(
    (s) => s.store.loadWorks(
      s.accountId,
      query: query,
      offset: offset,
      limit: limit,
    ),
  );
  @override
  Future<List<LocalMedia>> workFiles(
    int workId, {
    int offset = 0,
    int limit = 50,
    String? nextAfter,
  }) => _library(
    (s) => s.store.loadWorkFiles(
      s.accountId,
      workId,
      offset: offset,
      limit: limit,
      nextAfter: nextAfter,
    ),
  );
  @override
  Future<void> assignWork(MediaWork work, List<WorkFileEdit> files) =>
      _library((s) => s.store.assignWork(s.accountId, work, files));
  @override
  Future<void> unassignWork(List<String> versionKeys) =>
      _library((s) => s.store.unassignWork(s.accountId, versionKeys));

  @override
  Future<List<SourceImport>> imports() => _library((scope) async {
    final rows = await scope.store.loadImports(scope.accountId);
    final titles = <int, String>{};
    for (final row in rows) {
      _checkLibrary(scope, row.sourceId);
      final cached = _sources[row.sourceId]?.title;
      if (cached != null) {
        titles[row.sourceId] = cached;
      } else if (row.title.isEmpty) {
        await _ensureSource(scope, row.sourceId);
        _checkLibrary(scope, row.sourceId);
        titles[row.sourceId] = _sources[row.sourceId]!.title;
      }
    }
    if (titles.isNotEmpty) {
      await scope.store.describeSources(scope.accountId, titles);
    }
    return scope.store.loadImports(scope.accountId);
  });

  @override
  Future<List<WatchRecord>> history({
    int offset = 0,
    int limit = 50,
    bool unfinished = false,
    int? workId,
    List<String>? versionKeys,
  }) => _library(
    (scope) => scope.store.loadHistory(
      scope.accountId,
      offset: offset,
      limit: limit,
      unfinished: unfinished,
      workId: workId,
      versionKeys: versionKeys,
    ),
  );

  @override
  Future<void> removeHistory({String? versionKey}) => _library(
    (scope) =>
        scope.store.removeHistory(scope.accountId, versionKey: versionKey),
  );

  Future<void> _ensureSource(_LibraryScope scope, int sourceId) async {
    _checkLibrary(scope, sourceId);
    // TDLib may not know saved chat IDs after reopening without its chat database.
    while (!_sources.containsKey(sourceId) && _exhausted.length < 2) {
      await loadSources();
      _checkLibrary(scope, sourceId);
    }
    if (!_sources.containsKey(sourceId)) {
      throw const TelegramException(TelegramFailure.unavailable);
    }
  }

  @override
  Future<void> importNext(int sourceId) => _library((scope) async {
    _checkLibrary(scope, sourceId);
    await _ensureSource(scope, sourceId);
    final current = await scope.store.checkpoint(scope.accountId, sourceId);
    if (current.complete) return;
    if (current.paused) {
      throw const TelegramException(TelegramFailure.invalidInput);
    }
    final page = await TelegramHistoryService(scope.connection.request)
        .page(sourceId, current.nextMessageId);
    _checkLibrary(scope, sourceId);
    await scope.store.writeBatch(
      scope.accountId,
      sourceId,
      page.media,
      nextMessageId: page.nextMessageId,
      expectedRevision: current.revision,
      complete: page.nextMessageId == 0,
      newestMessageId: page.newestMessageId,
    );
  });

  @override
  Future<bool> updateNext(int sourceId) => _library((scope) async {
    await _ensureSource(scope, sourceId);
    final current = await scope.store.checkpoint(scope.accountId, sourceId);
    if (current.paused) {
      throw const TelegramException(TelegramFailure.invalidInput);
    }
    final update = await scope.store.updateCheckpoint(
      scope.accountId,
      sourceId,
    );
    final page = await TelegramHistoryService(scope.connection.request)
        .page(sourceId, update.cursor);
    _checkLibrary(scope, sourceId);
    final target = page.newestMessageId > update.target
        ? page.newestMessageId
        : update.target;
    final complete =
        page.nextMessageId == 0 ||
        (page.oldestMessageId > 0 &&
            page.oldestMessageId <= update.highWater) ||
        (page.nextMessageId > 0 && page.nextMessageId <= update.highWater);
    await scope.store.writeUpdateBatch(
      scope.accountId,
      sourceId,
      page.media.where((item) => item.messageId > update.highWater).toList(),
      expectedRevision: current.revision,
      checkpoint: UpdateCheckpoint(
        highWater: complete && target > update.highWater
            ? target
            : update.highWater,
        cursor: complete ? 0 : page.nextMessageId,
        target: complete ? 0 : target,
        checkedAt: complete ? DateTime.now().toUtc() : update.checkedAt,
      ),
    );
    return complete;
  });

  @override
  Future<void> pauseImport(int sourceId, bool paused) =>
      _library((scope) async {
        _checkLibrary(scope, sourceId);
        final current = await scope.store.checkpoint(scope.accountId, sourceId);
        _checkLibrary(scope, sourceId);
        await scope.store.setPaused(
          scope.accountId,
          sourceId,
          paused,
          expectedRevision: current.revision,
        );
      });

  Future<Map<String, dynamic>> _mediaMessage(
    _LibraryScope scope,
    LocalMedia item,
  ) async {
    _checkLibrary(scope, item.sourceId);
    final versions = await scope.store.loadVersions(
      scope.accountId,
      item.sourceId,
      item.messageId,
    );
    if (!versions.any((version) => version.versionKey == item.versionKey)) {
      throw const TelegramException(TelegramFailure.invalidInput);
    }
    await _ensureSource(scope, item.sourceId);
    // getMessageLink is offline; reopening restores metadata but not TDLib's message cache.
    final message = await scope.connection.request({
      '@type': 'getMessage',
      'chat_id': item.sourceId,
      'message_id': item.messageId,
    });
    _checkLibrary(scope, item.sourceId);
    if (message['@type'] != 'message' ||
        message['chat_id'] != item.sourceId ||
        message['id'] != item.messageId ||
        message['self_destruct_type'] != null) {
      throw const TelegramException(TelegramFailure.unavailable);
    }
    final file = videoFile(message);
    if (file == null ||
        (file['remote'] as Map?)?['unique_id'] != item.remoteUniqueId ||
        file['size'] != item.sizeBytes) {
      throw const TelegramException(TelegramFailure.unavailable);
    }
    return message;
  }

  @override
  Future<String> messageLink(LocalMedia item) => _library((scope) async {
    await _mediaMessage(scope, item);
    final properties = await scope.connection.request({
      '@type': 'getMessageProperties',
      'chat_id': item.sourceId,
      'message_id': item.messageId,
    });
    _checkLibrary(scope, item.sourceId);
    if (properties['@type'] != 'messageProperties' ||
        properties['can_get_link'] is! bool) {
      throw const TelegramException(TelegramFailure.unavailable);
    }
    if (properties['can_get_link'] != true) {
      throw const TelegramException(TelegramFailure.linkUnsupported);
    }
    final result = await scope.connection.request({
      '@type': 'getMessageLink',
      'chat_id': item.sourceId,
      'message_id': item.messageId,
      'media_timestamp': 0,
      'checklist_task_id': 0,
      'poll_option_id': '',
      'for_album': false,
      'in_message_thread': false,
    });
    _checkLibrary(scope, item.sourceId);
    final link = result['link'];
    final uri = link is String ? Uri.tryParse(link) : null;
    if (uri == null ||
        uri.scheme != 'https' ||
        !['t.me', 'telegram.me'].contains(uri.host)) {
      throw const TelegramException(TelegramFailure.unavailable);
    }
    return link as String;
  });

  Future<void> _closePlayback() async {
    ++_playbackGeneration;
    final source = _playback;
    _playback = null;
    _playingSource = null;
    await source?.close();
  }

  @override
  Future<PlaybackMedia> openPlayback(LocalMedia item) =>
      _library((scope) async {
        final closing = _closePlayback();
        final generation = _playbackGeneration;
        await closing;
        void check() {
          _checkLibrary(scope, item.sourceId);
          if (generation != _playbackGeneration) {
            throw const TelegramException(TelegramFailure.unavailable);
          }
        }

        final message = await _mediaMessage(scope, item);
        final position = await scope.store.loadProgress(
          scope.accountId,
          item.versionKey,
        );
        check();
        final source = await TelegramPlaybackSource.start(
          message: message,
          trace: playbackTrace,
          request: (request) async {
            // Cleanup still targets the captured connection after access is revoked.
            if (request['@type'] == 'cancelDownloadFile') {
              return scope.connection.request(request);
            }
            check();
            final result = await scope.connection.request(request);
            check();
            return result;
          },
          checkAccess: check,
          position: position ?? Duration.zero,
          savePosition:
              (position, {completed = false, duration = Duration.zero}) async {
                check();
                await scope.store.saveProgress(
                  scope.accountId,
                  item.versionKey,
                  position,
                  completed: completed,
                  duration: duration,
                );
                check();
              },
        );
        try {
          check();
          _playback = source;
          _playingSource = item.sourceId;
          return source;
        } catch (_) {
          await source.close();
          rethrow;
        }
      });

  @override
  Future<void> logout() async {
    if (_connection == null) return;
    await _closePlayback();
    try {
      if (_account.stage == TelegramStage.ready) {
        await _connection!.request({'@type': 'logOut'});
        await _connection?.waitForLogout?.call();
      }
      await _connection?.revokeRelay?.call();
    } finally {
      ++_generation;
      await _disconnect();
      _publish(TelegramAccount(stage: TelegramStage.disconnected));
    }
  }

  Future<void> _disconnect() async {
    await _closePlayback();
    await _subscription?.cancel();
    _subscription = null;
    final connection = _connection;
    _connection = null;
    await connection?.close();
    _sources.clear();
    _exhausted.clear();
    _limit = 0;
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    ++_generation;
    await _disconnect();
    await _opening?.catchError((Object _) {});
    await _accounts.close();
  }
}
