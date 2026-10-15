import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../domain/models/telegram_account.dart';
import '../../../../domain/ports/telegram_repository.dart';

class SourcesViewModel extends ChangeNotifier {
  SourcesViewModel(this._repository) : _account = _repository.account {
    _subscription = _repository.accounts.listen(_changed);
    _selected = Set.of(_account.selectedSources);
  }

  final TelegramRepository _repository;
  late final StreamSubscription<TelegramAccount> _subscription;
  TelegramAccount _account;
  List<TelegramSource> _sources = [];
  Set<int> _selected = {};
  String _query = '';
  bool _disposed = false;
  bool busy = false;
  bool loadingSources = false;
  bool hasMore = true;
  bool saved = false;
  TelegramFailure? failure;

  TelegramAccount get account => _account;
  String get query => _query;
  Set<int> get selected => Set.unmodifiable(_selected);
  List<TelegramSource> get sources => _sources
      .where(
        (source) => source.title.toLowerCase().contains(_query.toLowerCase()),
      )
      .toList();

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _changed(TelegramAccount value) {
    if (_disposed) return;
    final previous = _account;
    _account = value;
    if (value.failure != null) failure = value.failure;
    if (previous.stage != TelegramStage.ready || previous.id != value.id) {
      _sources = [];
      _query = '';
      _selected = Set.of(value.selectedSources);
      hasMore = true;
      saved = false;
      if (value.stage == TelegramStage.ready) unawaited(loadSources());
    }
    _notify();
  }

  Future<void> _run(Future<void> Function() operation) async {
    if (_disposed || busy) return;
    busy = true;
    failure = null;
    _notify();
    try {
      await operation();
    } on TelegramException catch (error) {
      if (!_disposed) failure = error.failure;
    } catch (_) {
      if (!_disposed) failure = TelegramFailure.connection;
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<void> connect() => _run(_repository.connect);
  Future<void> submit(String input) => _run(() => _repository.submit(input));
  Future<void> logout() => _run(_repository.logout);

  Future<void> loadSources() async {
    if (_disposed || loadingSources || _account.stage != TelegramStage.ready) {
      return;
    }
    loadingSources = true;
    failure = null;
    final id = _account.id;
    _notify();
    try {
      final page = await _repository.loadSources();
      if (!_disposed &&
          _account.id == id &&
          _account.stage == TelegramStage.ready) {
        _sources = page.sources;
        hasMore = page.hasMore;
      }
    } catch (_) {
      if (!_disposed && _account.id == id) failure = TelegramFailure.connection;
    } finally {
      loadingSources = false;
      _notify();
    }
  }

  void search(String value) {
    _query = value;
    _notify();
  }

  void select(int id, bool value) {
    if (busy ||
        _disposed ||
        _account.stage != TelegramStage.ready ||
        !_sources.any((source) => source.id == id)) {
      return;
    }
    value ? _selected.add(id) : _selected.remove(id);
    saved = false;
    _notify();
  }

  Future<void> save() => _run(() async {
    await _repository.saveSources(Set.of(_selected));
    if (!_disposed) saved = true;
  });

  Future<void> close() async {
    if (_disposed) return;
    _disposed = true;
    await Future.wait([_subscription.cancel(), _repository.close()]);
  }

  @override
  void dispose() {
    // Closing the client keeps the login; only an explicit logout revokes it.
    unawaited(close().catchError((Object _) {}));
    super.dispose();
  }
}
