import 'dart:async';

import '../../../domain/models/local_media.dart';
import '../../../domain/ports/media_playback_repository.dart';
import '../../../domain/ports/playback.dart';

class LibraryPlayback implements Playback {
  LibraryPlayback(
    this.repository,
    this.media,
    Playback Function(Future<Uri> Function()) create,
  ) {
    _backend = create(() async => _source!.uri);
    _subscription = _backend.states.listen((state) {
      _state = state;
      if (!_opening && !_invalid && state.status == PlaybackStatus.ready) {
        if (state.completed) {
          _completed = true;
          _position = Duration.zero;
          _recordProgress = true;
        } else if (state.position > Duration.zero &&
            (!_completed || state.playing)) {
          _completed = false;
          _position = state.position;
          _recordProgress = true;
        }
        if (state.completed) unawaited(_save());
      }
      _emit();
    });
  }

  final MediaPlaybackRepository repository;
  final LocalMedia media;
  late final Playback _backend;
  late final StreamSubscription<PlaybackState> _subscription;
  final _states = StreamController<PlaybackState>.broadcast();
  PlaybackState _state = const PlaybackState();
  PlaybackMedia? _source;
  Duration? _position;
  Timer? _timer;
  Future<void>? _openingTask;
  Future<void>? _saving;
  Future<void>? _disposing;
  bool _dirty = false;
  bool _completed = false;
  bool _recordProgress = false;
  (Duration, bool, Duration)? _lastSaved;
  bool _opening = false;
  bool _invalid = false;
  bool _disposed = false;
  bool _progressFailed = false;

  @override
  Stream<PlaybackState> get states => _states.stream;

  void _emit() {
    if (_disposed) return;
    _states.add(
      PlaybackState(
        status: _invalid ? PlaybackStatus.failed : _state.status,
        playing: !_invalid && _state.playing,
        buffering: _state.buffering,
        completed: _state.completed,
        position: _state.position,
        duration: _state.duration,
        progressFailed: _progressFailed,
      ),
    );
  }

  @override
  Future<void> open({Duration? position}) {
    if (_disposed) return Future.error(StateError('Playback closed'));
    return _openingTask ??= _open(position)
        .whenComplete(() => _openingTask = null);
  }

  Future<void> _open(Duration? position) async {
    _opening = true;
    _timer?.cancel();
    try {
      await _save();
      final previous = _source;
      _source = null;
      await previous?.close();
      final source = await repository.openPlayback(media);
      if (_disposed) {
        await source.close();
        return;
      }
      _source = source;
      _invalid = false;
      _position = position ?? source.position;
      _completed = false;
      _lastSaved = null;
      _recordProgress = position != null;
      unawaited(
        source.closed.then((_) async {
          if (_disposed || !identical(_source, source)) return;
          _invalid = true;
          _timer?.cancel();
          _emit();
          try {
            await _backend.setPlaying(false);
          } catch (_) {}
        }),
      );
      await _backend.open(position: _position);
      if (_disposed || _invalid) {
        await _backend.setPlaying(false);
        return;
      }
      _timer = Timer.periodic(
        const Duration(seconds: 5),
        (_) => unawaited(_save()),
      );
    } catch (_) {
      _invalid = true;
      try {
        await _backend.setPlaying(false);
      } catch (_) {}
      final source = _source;
      _source = null;
      await source?.close();
      _emit();
      rethrow;
    } finally {
      _opening = false;
    }
  }

  Future<void> _save() {
    if (_source == null || _position == null || _invalid || !_recordProgress) {
      return Future.value();
    }
    if (_lastSaved == (_position!, _completed, _state.duration)) {
      return Future.value();
    }
    _dirty = true;
    return _saving ??= _write().whenComplete(() => _saving = null);
  }

  Future<void> _write() async {
    while (_dirty && _source != null && !_invalid) {
      _dirty = false;
      try {
        final snapshot = (_position!, _completed, _state.duration);
        await _source!.savePosition(
          snapshot.$1,
          completed: snapshot.$2,
          duration: snapshot.$3,
        );
        _lastSaved = snapshot;
        _progressFailed = false;
      } catch (_) {
        _progressFailed = true;
      }
      _emit();
    }
  }

  @override
  Future<void> setPlaying(bool playing) async {
    if (_disposed) return;
    if (_invalid && playing) throw StateError('Playback unavailable');
    await _backend.setPlaying(playing);
    if (!playing) await _save();
  }

  @override
  Future<void> seek(Duration position) async {
    if (_disposed || _invalid) throw StateError('Playback unavailable');
    await _backend.seek(position);
    _position = position;
    _completed = false;
    _recordProgress = true;
    await _save();
  }

  @override
  Future<void> dispose() => _disposing ??= _dispose();

  Future<void> _dispose() async {
    _disposed = true;
    _timer?.cancel();
    await _save();
    final source = _source;
    _source = null;
    try {
      await source?.close();
      await _openingTask?.catchError((Object _) {});
    } finally {
      await _subscription.cancel();
      try {
        await _backend.dispose();
      } finally {
        await _states.close();
      }
    }
  }
}
