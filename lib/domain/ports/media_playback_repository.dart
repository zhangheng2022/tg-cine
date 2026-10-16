import '../models/local_media.dart';

abstract interface class MediaPlaybackRepository {
  Future<PlaybackMedia> openPlayback(LocalMedia media);
}

/// A source tied to one account, selected source and actual file version.
abstract interface class PlaybackMedia {
  Uri get uri;
  Duration get position;
  Future<void> get closed;
  Future<void> savePosition(
    Duration position, {
    bool completed = false,
    Duration duration = Duration.zero,
  });
  Future<void> close();
}
