import 'dart:async';

import 'package:media_kit/media_kit.dart';

import '../../../domain/ports/playback.dart';
import 'native_playback_options_stub.dart'
    if (dart.library.io) 'native_playback_options_io.dart';

class MediaKitPlayback implements Playback {
  MediaKitPlayback({required this.source, this.separateAudio = false}) {
    MediaKit.ensureInitialized();
    player = Player(
      configuration: const PlayerConfiguration(
        title: 'TG Cine',
        bufferSize: 8 * 1024 * 1024,
        logLevel: MPVLogLevel.error,
      ),
    );
    _subscriptions.addAll([
      player.stream.playing.listen((_) => _emit()),
      player.stream.position.listen((_) => _emit()),
      player.stream.duration.listen((_) => _emit()),
      player.stream.buffering.listen((_) => _emit()),
      player.stream.completed.listen((_) => _emit()),
      player.stream.error.listen((_) {
        _failed = true;
        _emit();
      }),
    ]);
  }

  final Future<Uri> Function() source;
  final bool separateAudio;
  late final Player player;
  final _states = StreamController<PlaybackState>.broadcast();
  final _subscriptions = <StreamSubscription<dynamic>>[];
  bool _opening = false;
  bool _failed = false;
  bool _disposed = false;

  @override
  Stream<PlaybackState> get states => _states.stream;

  void _emit() {
    if (_disposed) return;
    final state = player.state;
    _states.add(
      PlaybackState(
        status: _failed
            ? PlaybackStatus.failed
            : _opening || state.duration == Duration.zero
            ? PlaybackStatus.loading
            : PlaybackStatus.ready,
        playing: state.playing,
        buffering: state.buffering,
        completed: state.completed,
        position: state.position,
        duration: state.duration,
      ),
    );
  }

  @override
  Future<void> open() async {
    _failed = false;
    _opening = true;
    _emit();
    try {
      final uri = await source();
      await configureNativePlayback(player);
      await player.open(Media(uri.toString()), play: false);
      if (separateAudio) await configureNativeAudio(player, uri);
      await player.play();
    } catch (_) {
      _failed = true;
      // Native errors can include the private URL; expose only a safe failure state.
      throw StateError('Playback unavailable');
    } finally {
      _opening = false;
      _emit();
    }
  }

  @override
  Future<void> setPlaying(bool playing) =>
      playing ? player.play() : player.pause();

  @override
  Future<void> seek(Duration position) => player.seek(position);

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    await player.dispose();
    await _states.close();
  }
}
