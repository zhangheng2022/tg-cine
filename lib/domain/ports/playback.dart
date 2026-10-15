enum PlaybackStatus { idle, loading, ready, failed }

class PlaybackState {
  const PlaybackState({
    this.status = PlaybackStatus.idle,
    this.playing = false,
    this.buffering = false,
    this.completed = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
  });

  final PlaybackStatus status;
  final bool playing;
  final bool buffering;
  final bool completed;
  final Duration position;
  final Duration duration;
}

abstract interface class Playback {
  Stream<PlaybackState> get states;
  Future<void> open();
  Future<void> setPlaying(bool playing);
  Future<void> seek(Duration position);
  Future<void> dispose();
}
