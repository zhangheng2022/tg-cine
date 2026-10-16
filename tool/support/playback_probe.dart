import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'local_media_server.dart';
import 'media_probe.dart';

/// shortcut: Windows/VLC video-only proof; replace when Flutter playback is wired.
Future<Map<String, dynamic>> verifyPlayback(
  MediaProbe media,
  Directory privateDirectory,
) async {
  final executable = File(r'C:\Program Files\VideoLAN\VLC\vlc.exe');
  if (!Platform.isWindows || !await executable.exists()) {
    throw UnsupportedError('Windows VLC is required');
  }
  if (media.duration == null || media.duration! < 4) {
    throw StateError('Known video duration required');
  }
  const decoderTimeout = Duration(minutes: 8);
  final output = await privateDirectory.createTemp('playback-probe-');
  final segments = <Map<String, dynamic>>[];
  Map<String, dynamic>? preparation;
  for (final start in [0, media.duration! ~/ 2]) {
    final frames = await Directory.fromUri(
      output.uri.resolve('segment-$start/'),
    ).create();
    final segmentTimer = Stopwatch()..start();
    final server = await LocalMediaServer.start(
      size: media.size,
      mimeType: media.mimeType,
      read: media.read,
      cancelRead: media.cancelPendingRead,
    );
    Process? decoder;
    var code = -1;
    var frameBytes = 0;
    int? firstFrameDetectedMs;
    final frame = File.fromUri(frames.uri.resolve('frame.png'));
    final frameWatch = Timer.periodic(const Duration(milliseconds: 100), (
      timer,
    ) {
      try {
        if (frame.existsSync() && frame.lengthSync() >= 24) {
          firstFrameDetectedMs = segmentTimer.elapsedMilliseconds;
          timer.cancel();
        }
      } on FileSystemException {
        // VLC may still be replacing the image during this check.
      }
    });
    final progress = Timer.periodic(const Duration(seconds: 30), (_) {
      stdout.writeln(
        jsonEncode({
          'status': 'decoder-progress',
          'startSeconds': start,
          'bytesServed': server.bytesServed,
          'pendingRequests': server.pendingRequests,
          'rangeRequests': server.rangeRequests,
          'failedRequests': server.failedRequests,
        }),
      );
    });
    try {
      if (start == 0) preparation = await media.preparePlayback();
      stdout.writeln(
        '正在验证 VLC 解码：从 $start 秒开始，最多等待 ${decoderTimeout.inMinutes} 分钟。',
      );
      decoder = await Process.start(executable.path, [
        '--intf=dummy',
        '--no-one-instance',
        '--ignore-config',
        '--no-media-library',
        '--no-audio',
        '--vout=dummy',
        '--video-filter=scene',
        '--scene-format=png',
        '--scene-width=640',
        '--scene-height=360',
        '--scene-ratio=1',
        '--scene-replace',
        '--scene-prefix=frame',
        '--scene-path=${frames.path}',
        '--start-time=$start',
        '--run-time=2',
        '--play-and-exit',
        '--no-video-title-show',
        server.uri.toString(),
      ], mode: ProcessStartMode.normal);
      final drains = [
        decoder.stdout.drain<void>(),
        decoder.stderr.drain<void>(),
      ];
      code = await decoder.exitCode.timeout(decoderTimeout);
      await Future.wait(drains);
      final data = await frame.readAsBytes();
      if (code != 0 ||
          data.length < 24 ||
          data.take(8).join(',') != '137,80,78,71,13,10,26,10') {
        throw StateError('VLC did not produce a decoded PNG frame');
      }
      frameBytes = data.length;
      stdout.writeln('VLC 在 $start 秒的解码画面已生成。');
    } finally {
      frameWatch.cancel();
      progress.cancel();
      if (decoder != null) {
        decoder.kill();
        await decoder.exitCode;
      }
      await server.close();
    }
    segments.add({
      'startSeconds': start,
      'decoderExitCode': code,
      'decodedFrameBytes': frameBytes,
      'firstFrameDetectedMs': firstFrameDetectedMs,
      'bytesServed': server.bytesServed,
      'ranges': server.ranges,
      'failedRequests': server.failedRequests,
    });
  }
  return {
    'checkedAt': DateTime.now().toUtc().toIso8601String(),
    'status': 'decoder-segments-verified',
    'player': 'VLC',
    'segments': segments,
    'preparation': preparation,
    'interactiveSeekVerified': false,
    'continuousPlaybackVerified': false,
    'audioVerified': false,
    'flutterPlayerVerified': false,
  };
}
