import '../../../../domain/models/media_organization.dart';
import '../../../../domain/models/watch_record.dart';
import '../../../../domain/models/media_work.dart';

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../domain/models/local_media.dart';
import '../../../../domain/models/telegram_account.dart';
import '../../../../domain/ports/media_library_repository.dart';
import '../../../../domain/ports/telegram_repository.dart';

class LibraryViewModel extends ChangeNotifier {
  LibraryViewModel(this._repository, TelegramRepository telegram)
    : _account = telegram.account {
    _subscription = telegram.accounts.listen(_changed);
    if (ready) unawaited(refresh());
  }
  final MediaLibraryRepository _repository;
  late final StreamSubscription<TelegramAccount> _subscription;
  TelegramAccount _account;
  List<LocalMedia> _media = [];
  List<WatchRecord> history = [];
  List<WatchRecord> continuing = [];
  bool historyLoading = false;
  bool historyBusy = false;
  bool historyHasMore = false;
  TelegramFailure? historyFailure;
  int _historyRead = 0;
  int _scope = 0;
  int _historyVisible = 50;

  Future<void> refreshHistory({bool more = false}) async {
    if (_disposed || !ready || (more && historyLoading)) return;
    final read = ++_historyRead;
    historyLoading = true;
    historyFailure = null;
    if (more) _historyVisible += 50;
    _notify();
    try {
      final records = <WatchRecord>[];
      var next = false;
      for (var offset = 0; offset < _historyVisible; offset += 50) {
        final page = await _repository.history(offset: offset);
        if (_disposed || read != _historyRead) return;
        records.addAll(page);
        next = page.length == 50;
        if (!next) break;
      }
      final recent = await _repository.history(limit: 5, unfinished: true);
      if (_disposed || read != _historyRead) return;
      history = records;
      continuing = recent;
      historyHasMore = next;
    } on TelegramException catch (error) {
      if (read == _historyRead) historyFailure = error.failure;
    } catch (_) {
      if (read == _historyRead) historyFailure = TelegramFailure.storage;
    } finally {
      if (!_disposed && read == _historyRead) {
        historyLoading = false;
        _notify();
      }
    }
  }

  Future<void> removeHistory({String? versionKey}) async {
    if (_disposed || !ready || historyBusy) return;
    final scope = _scope;
    ++_historyRead;
    historyBusy = true;
    historyFailure = null;
    _notify();
    try {
      await _repository.removeHistory(versionKey: versionKey);
      if (_disposed || scope != _scope) return;
      await refreshHistory();
    } catch (_) {
      if (!_disposed && scope == _scope) {
        historyFailure = TelegramFailure.storage;
      }
    } finally {
      if (!_disposed && scope == _scope) {
        historyBusy = false;
        _notify();
      }
    }
  }

  List<SourceImport> _imports = [];
  LocalMedia? selected;
  String query = '';
  MediaKind? kind;

  void filter(MediaKind? value) {
    kind = value;
    _visible = 50;
    unawaited(refresh());
  }

  Future<void> saveOrganization(
    LocalMedia media,
    MediaOrganization? value,
  ) async {
    final scope = _scope;
    await _repository.saveOrganization(media, value);
    if (_disposed || scope != _scope) return;
    await refresh();
  }

  int queryRevision = 0;
  bool loading = false;
  bool hasMore = false;
  bool pausing = false;
  bool showImports = true;
  int _visible = 50;
  bool _loaded = false;
  int? runningSource;
  bool updating = false;
  TelegramFailure? failure;
  bool _disposed = false;
  bool _active = true;
  int _read = 0;
  int _run = 0;
  Future<void>? _pauseOperation;

  int get accountRevision => _scope;
  Future<T> _workRead<T>(Future<T> Function() read) async {
    final scope = _scope;
    if (!ready || _disposed) {
      throw const TelegramException(TelegramFailure.invalidInput);
    }
    final result = await read();
    if (_disposed || scope != _scope) {
      throw const TelegramException(TelegramFailure.invalidInput);
    }
    return result;
  }

  Future<List<MediaWork>> works({String query = '', int offset = 0}) =>
      _workRead(() => _repository.works(query: query, offset: offset));
  Future<List<LocalMedia>> workFiles(
    int id, {
    int offset = 0,
    String? nextAfter,
  }) => _workRead(
    () => _repository.workFiles(id, offset: offset, nextAfter: nextAfter),
  );
  Future<List<WatchRecord>> workHistory(
    int id, {
    List<String>? versionKeys,
    bool unfinished = false,
    int limit = 50,
  }) => _workRead(
    () => _repository.history(
      workId: id,
      versionKeys: versionKeys,
      unfinished: unfinished,
      limit: limit,
    ),
  );
  Future<List<LocalMedia>> organizationFiles({
    String query = '',
    int offset = 0,
    bool unresolved = false,
  }) => _workRead(
    () => _repository.media(
      query: query,
      offset: offset,
      kind: unresolved ? MediaKind.unresolved : null,
    ),
  );
  Future<void> assignWork(
    int scope,
    MediaWork work,
    List<WorkFileEdit> files,
  ) async {
    if (scope != _scope || !ready || _disposed) {
      throw const TelegramException(TelegramFailure.invalidInput);
    }
    await _workRead(() => _repository.assignWork(work, files));
    await refresh();
  }

  Future<void> unassignWork(int scope, List<String> keys) async {
    if (scope != _scope || !ready || _disposed) {
      throw const TelegramException(TelegramFailure.invalidInput);
    }
    await _workRead(() => _repository.unassignWork(keys));
    await refresh();
  }

  bool get ready => _account.stage == TelegramStage.ready;
  List<LocalMedia> get media => List.unmodifiable(_media);
  List<SourceImport> get imports => List.unmodifiable(_imports);
  String sourceTitle(int id) =>
      _imports.where((source) => source.sourceId == id).firstOrNull?.title ??
      '';
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _changed(TelegramAccount value) {
    final reset =
        value.id != _account.id ||
        value.stage != _account.stage ||
        !setEquals(value.selectedSources, _account.selectedSources);
    _account = value;
    if (!reset || _disposed) return;
    ++_run;
    ++_read;
    ++_historyRead;
    ++_scope;
    history = [];
    continuing = [];
    historyLoading = false;
    historyBusy = false;
    historyFailure = null;
    historyHasMore = false;
    _historyVisible = 50;
    runningSource = null;
    pausing = false;
    _pauseOperation = null;
    selected = null;
    _media = [];
    _imports = [];
    failure = null;
    loading = false;
    query = '';
    kind = null;
    ++queryRevision;
    _visible = 50;
    _loaded = false;
    _notify();
    if (ready) unawaited(refresh());
  }

  Future<void> refresh({bool more = false}) async {
    if (_disposed || !ready || (more && loading)) return;
    unawaited(refreshHistory());
    final read = ++_read;
    loading = true;
    failure = null;
    _notify();
    try {
      final rows = await _repository.imports();
      if (more) _visible += 50;
      final items = <LocalMedia>[];
      var next = false;
      for (var offset = 0; offset < _visible; offset += 50) {
        final page = await _repository.media(
          offset: offset,
          query: query,
          kind: kind,
        );
        if (_disposed || read != _read || !ready) return;
        items.addAll(page);
        next = page.length == 50;
        if (!next) break;
      }
      if (_disposed || read != _read || !ready) return;
      _imports = rows;
      if (!_loaded) {
        showImports = items.isEmpty;
        _loaded = true;
      }
      _media = items;
      if (selected != null) {
        selected = items
            .where((item) => item.versionKey == selected!.versionKey)
            .firstOrNull;
      }
      hasMore = next;
    } on TelegramException catch (error) {
      if (!_disposed && read == _read) failure = error.failure;
    } catch (_) {
      if (!_disposed && read == _read) failure = TelegramFailure.connection;
    } finally {
      if (!_disposed && read == _read) {
        loading = false;
        _notify();
      }
    }
  }

  void search(String value) {
    if (value.length > 1000) return;
    query = value;
    _visible = 50;
    unawaited(refresh());
  }

  void toggleImports() {
    showImports = !showImports;
    _notify();
  }

  void clearSearch() {
    ++queryRevision;
    search('');
  }

  void select(LocalMedia value) {
    if (_disposed ||
        !ready ||
        !_media.any((item) => item.versionKey == value.versionKey)) {
      return;
    }
    selected = value;
    _notify();
  }

  Future<void> start(int sourceId, {bool updates = false}) async {
    if (_disposed || !_active || !ready || runningSource != null || pausing) {
      return;
    }
    final run = ++_run;
    runningSource = sourceId;
    updating = updates;
    failure = null;
    _notify();
    try {
      await _repository.pauseImport(sourceId, false);
      while (!_disposed && _active && run == _run && ready) {
        var updatesComplete = false;
        if (updates) {
          updatesComplete = await _repository.updateNext(sourceId);
        } else {
          await _repository.importNext(sourceId);
        }
        if (_disposed || run != _run) break;
        await refresh();
        final source = _imports
            .where((row) => row.sourceId == sourceId)
            .firstOrNull;
        if (failure != null ||
            source == null ||
            (updates ? updatesComplete : source.checkpoint.complete) ||
            source.checkpoint.paused) {
          break;
        }
        await Future<void>.delayed(const Duration(milliseconds: 750));
      }
    } on TelegramException catch (error) {
      if (!_disposed && run == _run) failure = error.failure;
    } catch (_) {
      if (!_disposed && run == _run) failure = TelegramFailure.connection;
    } finally {
      if (!_disposed && run == _run) {
        runningSource = null;
        _notify();
      }
    }
  }

  Future<void> pause() {
    if (_pauseOperation case final operation?) return operation;
    final sourceId = runningSource;
    if (_disposed || sourceId == null) return Future.value();
    final operation = _pause(sourceId);
    _pauseOperation = operation;
    return operation.whenComplete(() {
      if (identical(_pauseOperation, operation)) _pauseOperation = null;
    });
  }

  Future<void> _pause(int sourceId) async {
    final run = ++_run;
    runningSource = null;
    pausing = true;
    _notify();
    try {
      await _repository.pauseImport(sourceId, true);
      if (!_disposed && run == _run) await refresh();
    } on TelegramException catch (error) {
      if (!_disposed && run == _run) failure = error.failure;
    } catch (_) {
      if (!_disposed && run == _run) failure = TelegramFailure.storage;
    } finally {
      if (!_disposed && run == _run) {
        pausing = false;
        _notify();
      }
    }
  }

  void activate(bool active) {
    _active = active;
    if (!active) {
      unawaited(pause());
    } else if (ready) {
      unawaited(refresh());
    }
  }

  Future<String> messageLink(LocalMedia value) =>
      _repository.messageLink(value);

  @override
  void dispose() {
    _disposed = true;
    ++_run;
    ++_read;
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
