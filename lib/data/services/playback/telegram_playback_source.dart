import 'dart:async';

import '../../../domain/ports/media_playback_repository.dart';
import 'local_media_server.dart';
import 'media_probe.dart';
import 'playback_trace.dart';

class TelegramPlaybackSource implements PlaybackMedia {
  TelegramPlaybackSource._(
    this._media,
    this._server,
    this.position,
    this._save,
  );

  final MediaProbe _media;
  final LocalMediaServer _server;
  @override
  final Duration position;
  final Future<void> Function(Duration, {bool completed, Duration duration})
  _save;
  final _closed = Completer<void>();
  Future<void>? _closing;

  static Future<TelegramPlaybackSource> start({
    required Map<String, dynamic> message,
    required Future<Map<String, dynamic>> Function(Map<String, dynamic>)
    request,
    PlaybackTrace? trace,
    required void Function() checkAccess,
    required Duration position,
    required Future<void> Function(
      Duration, {
      bool completed,
      Duration duration,
    })
    savePosition,
  }) async {
    final media = MediaProbe.fromMessage(message, request, trace: trace);
    try {
      final server = await LocalMediaServer.start(
        size: media.size,
        trace: trace,
        mimeType: media.mimeType,
        read: (offset, count) {
          checkAccess();
          return media.read(offset, count);
        },
        readReady: (offset, count) {
          checkAccess();
          return media.readReady(offset, count);
        },
        cancelRead: media.cancelPendingRead,
        maxBytes: null,
        maxRanges: null,
        separateStreams: true,
      );
      return TelegramPlaybackSource._(media, server, position, savePosition);
    } catch (_) {
      await media.close();
      rethrow;
    }
  }

  @override
  Uri get uri => _server.uri;
  @override
  Future<void> get closed => _closed.future;
  @override
  Future<void> savePosition(
    Duration position, {
    bool completed = false,
    Duration duration = Duration.zero,
  }) async {
    if (_closed.isCompleted) throw StateError('Media source closed');
    await _save(position, completed: completed, duration: duration);
  }

  @override
  Future<void> close() => _closing ??= _close();

  Future<void> _close() async {
    _closed.complete();
    try {
      await _server.close();
    } finally {
      // The native connection can already be gone during account shutdown.
      await _media.close().catchError((Object _) {});
    }
  }
}
