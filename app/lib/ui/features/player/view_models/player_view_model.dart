import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../domain/ports/playback.dart';

class PlayerViewModel extends ChangeNotifier {
  PlayerViewModel(this._playback) {
    _subscription = _playback.states.listen((state) {
      if (!_disposed) {
        _state = state;
        notifyListeners();
      }
    });
  }

  final Playback _playback;
  late final StreamSubscription<PlaybackState> _subscription;
  PlaybackState _state = const PlaybackState();
  PlaybackState get state => _state;
  bool _busy = false;
  bool get busy => _busy;
  bool _disposed = false;
  bool _active = false;

  Future<void> enter() async {
    _active = true;
    if (_state.status == PlaybackStatus.idle ||
        _state.status == PlaybackStatus.failed) {
      await open();
    }
  }

  Future<void> leave() async {
    _active = false;
    try {
      await _playback.setPlaying(false);
    } catch (_) {
      // The source may already be closing when the application exits.
    }
  }

  Future<void> open() => _run(() async {
    _state = const PlaybackState(status: PlaybackStatus.loading);
    notifyListeners();
    await _playback.open();
    if (!_active || _disposed) await _playback.setPlaying(false);
  });

  Future<void> toggle() => _run(() async {
    if (_state.status != PlaybackStatus.ready) return;
    if (_state.completed) await _playback.seek(Duration.zero);
    await _playback.setPlaying(_state.completed || !_state.playing);
    if (!_active || _disposed) await _playback.setPlaying(false);
  });

  Future<void> seek(Duration position) => _run(() async {
    if (_state.status != PlaybackStatus.ready) return;
    await _playback.seek(
      Duration(
        milliseconds: position.inMilliseconds.clamp(
          0,
          _state.duration.inMilliseconds,
        ),
      ),
    );
  });

  Future<void> _run(Future<void> Function() action) async {
    if (_busy || _disposed) return;
    _busy = true;
    notifyListeners();
    try {
      await action();
    } catch (_) {
      _state = const PlaybackState(status: PlaybackStatus.failed);
    } finally {
      _busy = false;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_subscription.cancel());
    unawaited(_playback.dispose().catchError((Object _) {}));
    super.dispose();
  }
}
