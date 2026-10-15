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
  List<SourceImport> _imports = [];
  LocalMedia? selected;
  String query = '';
  int queryRevision = 0;
  bool loading = false;
  bool hasMore = false;
  bool pausing = false;
  bool showImports = true;
  int _visible = 50;
  bool _loaded = false;
  int? runningSource;
  TelegramFailure? failure;
  bool _disposed = false;
  bool _active = true;
  int _read = 0;
  int _run = 0;
  Future<void>? _pauseOperation;

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
    runningSource = null;
    pausing = false;
    _pauseOperation = null;
    selected = null;
    _media = [];
    _imports = [];
    failure = null;
    loading = false;
    query = '';
    ++queryRevision;
    _visible = 50;
    _loaded = false;
    _notify();
    if (ready) unawaited(refresh());
  }

  Future<void> refresh({bool more = false}) async {
    if (_disposed || !ready || (more && loading)) return;
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
        final page = await _repository.media(offset: offset, query: query);
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

  Future<void> start(int sourceId) async {
    if (_disposed || !_active || !ready || runningSource != null || pausing) {
      return;
    }
    final run = ++_run;
    runningSource = sourceId;
    failure = null;
    _notify();
    try {
      await _repository.pauseImport(sourceId, false);
      while (!_disposed && _active && run == _run && ready) {
        await _repository.importNext(sourceId);
        if (_disposed || run != _run) break;
        await refresh();
        final source = _imports
            .where((row) => row.sourceId == sourceId)
            .firstOrNull;
        if (failure != null ||
            source == null ||
            source.checkpoint.complete ||
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
