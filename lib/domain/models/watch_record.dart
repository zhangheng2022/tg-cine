import 'local_media.dart';

class WatchRecord {
  const WatchRecord({
    required this.media,
    required this.sourceTitle,
    required this.position,
    required this.duration,
    required this.completed,
    required this.available,
    this.watchedAt,
  });

  final LocalMedia media;
  final String sourceTitle;
  final Duration position;
  final Duration duration;
  final DateTime? watchedAt;
  final bool completed;
  final bool available;
}
