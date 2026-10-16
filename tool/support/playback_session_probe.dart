import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'local_media_server.dart';
import 'media_probe.dart';

/// Only numeric playback evidence is retained; VLC metadata may contain secrets.
Map<String, int> playbackSnapshot(Map<String, dynamic> status) {
  final stats = status['stats'];
  if (stats is! Map || status['state'] != 'playing') {
    throw StateError('Decoder is not playing');
  }
  final values = {
    'timeSeconds': status['time'],
    'decodedVideo': stats['decodedvideo'],
    'decodedAudio': stats['decodedaudio'],
    'displayedVideo': stats['displayedpictures'],
    'playedAudio': stats['playedabuffers'],
    'lostPictures': stats['lostpictures'],
    'lostAudioBuffers': stats['lostabuffers'],
  };
  if (values.values.any((value) => value is! int || value < 0)) {
    throw const FormatException('Invalid decoder counters');
  }
  return values.map((key, value) => MapEntry(key, value as int));
}

Map<String, dynamic> summarizePlayback(List<Map<String, int>> samples) {
  if (samples.length < 2) {
    throw const FormatException('Missing playback samples');
  }
  var lastAdvance = samples.first['elapsedMs']!;
  var maximumStall = 0;
  var lastVideoAdvance = lastAdvance;
  var lastAudioAdvance = lastAdvance;
  var maximumVideoStall = 0;
  var maximumAudioStall = 0;
  for (var index = 1; index < samples.length; index++) {
    final current = samples[index];
    final previous = samples[index - 1];
    if (current['elapsedMs']! <= previous['elapsedMs']! ||
        current['timeSeconds']! < previous['timeSeconds']! ||
        current['decodedVideo']! < previous['decodedVideo']! ||
        current['decodedAudio']! < previous['decodedAudio']! ||
        current['displayedVideo']! < previous['displayedVideo']! ||
        current['playedAudio']! < previous['playedAudio']!) {
      throw const FormatException('Non-monotonic playback samples');
    }
    // Count the entire gap, including the poll where playback finally resumes.
    maximumStall = max(maximumStall, current['elapsedMs']! - lastAdvance);
    maximumVideoStall = max(
      maximumVideoStall,
      current['elapsedMs']! - lastVideoAdvance,
    );
    maximumAudioStall = max(
      maximumAudioStall,
      current['elapsedMs']! - lastAudioAdvance,
    );
    if (current['timeSeconds']! > previous['timeSeconds']!) {
      lastAdvance = current['elapsedMs']!;
    }
    if (current['displayedVideo']! > previous['displayedVideo']!) {
      lastVideoAdvance = current['elapsedMs']!;
    }
    if (current['playedAudio']! > previous['playedAudio']!) {
      lastAudioAdvance = current['elapsedMs']!;
    }
  }
  final first = samples.first;
  final last = samples.last;
  final elapsed = last['elapsedMs']! - first['elapsedMs']!;
  final advanced = last['timeSeconds']! - first['timeSeconds']!;
  final video = last['decodedVideo']! - first['decodedVideo']!;
  final audio = last['decodedAudio']! - first['decodedAudio']!;
  return {
    'elapsedMs': elapsed,
    'advancedSeconds': advanced,
    'decodedVideoDelta': video,
    'decodedAudioDelta': audio,
    'displayedVideoDelta': last['displayedVideo']! - first['displayedVideo']!,
    'playedAudioDelta': last['playedAudio']! - first['playedAudio']!,
    'maximumNoAdvanceMs': maximumStall,
    'maximumVideoNoOutputMs': maximumVideoStall,
    'maximumAudioNoOutputMs': maximumAudioStall,
    'lostPicturesDelta': last['lostPictures']! - first['lostPictures']!,
    'lostAudioBuffersDelta':
        last['lostAudioBuffers']! - first['lostAudioBuffers']!,
    'continuousVerified':
        elapsed >= 10000 &&
        advanced >= elapsed ~/ 1000 - 3 &&
        advanced <= elapsed ~/ 1000 + 3 &&
        maximumStall <= 5000 &&
        maximumVideoStall <= 5000 &&
        maximumAudioStall <= 5000 &&
        last['lostPictures'] == first['lostPictures'] &&
        last['lostAudioBuffers'] == first['lostAudioBuffers'] &&
        last['decodedVideo']! > 0 &&
        last['decodedAudio']! > 0 &&
        last['displayedVideo']! > first['displayedVideo']! &&
        last['playedAudio']! > first['playedAudio']!,
    'audioDecoded': last['decodedAudio']! > 0,
  };
}

/// shortcut: Windows VLC control proof; Flutter gestures and audible output need separate acceptance.
Future<Map<String, dynamic>> verifyPlaybackSession(
  MediaProbe media,
  Directory privateDirectory,
) async {
  final executable = File(r'C:\Program Files\VideoLAN\VLC\vlc.exe');
  if (!Platform.isWindows ||
      !await executable.exists() ||
      media.duration == null ||
      media.duration! < 180) {
    throw UnsupportedError(
      'Windows VLC and a video of at least 180 seconds required',
    );
  }
  final reportFile = File.fromUri(
    privateDirectory.uri.resolve('playback-session-probe.json'),
  );
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 2);
  client.findProxy = (_) => 'DIRECT';
  final report = <String, dynamic>{
    'checkedAt': DateTime.now().toUtc().toIso8601String(),
    'status': 'verifying-playback-session',
    'player': 'VLC',
    'audioOutput': 'mmdevice-muted',
    'playerPrefetchBytes': 16 * 1024 * 1024,
    'playerReadBytes': 64 * 1024,
    'networkCachingMs': 5000,
    'windows': <Map<String, dynamic>>[],
    'programmaticSeekVerified': false,
    'continuousPlaybackVerified': false,
    'audioDecoded': false,
    'audibleOutputVerified': false,
    'interactiveSeekVerified': false,
    'flutterPlayerVerified': false,
  };
  LocalMediaServer? server;
  Process? decoder;
  List<Future<void>> drains = [];
  var phase = 'preparation';
  try {
    final preparationTimer = Stopwatch()..start();
    final preparation = await media.preparePlayback();
    final headBytes = min(media.size, 8 * 1024 * 1024);
    for (var offset = 0; offset < headBytes;) {
      final count = min(MediaProbe.chunkSize, headBytes - offset);
      await media.read(offset, count);
      offset += count;
    }
    report['preparation'] = {
      ...preparation,
      'headWarmBytes': headBytes,
      'totalElapsedMs': preparationTimer.elapsedMilliseconds,
    };
    server = await LocalMediaServer.start(
      size: media.size,
      mimeType: media.mimeType,
      read: media.read,
      cancelRead: media.cancelPendingRead,
      maxBytes: 128 * 1024 * 1024,
      maxRanges: 512,
    );
    final reservation = await ServerSocket.bind(
      InternetAddress.loopbackIPv4,
      0,
    );
    final port = reservation.port;
    await reservation.close();
    final password = base64UrlEncode(
      List.generate(24, (_) => Random.secure().nextInt(256)),
    );
    final control = Uri(
      scheme: 'http',
      host: '127.0.0.1',
      port: port,
      path: '/requests/status.json',
    );
    decoder = await Process.start(executable.path, [
      '--intf=http',
      '--http-host=127.0.0.1',
      '--http-port=$port',
      '--http-password=$password',
      '--no-one-instance',
      '--ignore-config',
      '--no-media-library',
      '--vout=dummy',
      '--aout=mmdevice',
      '--mmdevice-volume=0',
      '--no-volume-save',
      '--stats',
      '--prefetch-buffer-size=16384',
      '--prefetch-read-size=65536',
      '--network-caching=5000',
      '--no-video-title-show',
      server.uri.toString(),
    ]);
    drains = [decoder.stdout.drain<void>(), decoder.stderr.drain<void>()];
    Future<Map<String, int>> snapshot({int? seek}) async {
      final request = await client.getUrl(
        control.replace(
          queryParameters: seek == null
              ? null
              : {'command': 'seek', 'val': '$seek'},
        ),
      );
      request.followRedirects = false;
      request.headers.set(
        HttpHeaders.authorizationHeader,
        'Basic ${base64Encode(utf8.encode(':$password'))}',
      );
      final response = await request.close();
      if (response.statusCode != 200) {
        await response.drain<void>();
        throw StateError('Decoder control rejected');
      }
      final bytes = <int>[];
      await for (final chunk in response) {
        if (bytes.length + chunk.length > 256 * 1024) {
          throw StateError('Decoder control response too large');
        }
        bytes.addAll(chunk);
      }
      final status = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      final stats = status['stats'];
      report['lastDecoderState'] = {
        'state': ['playing', 'paused', 'stopped'].contains(status['state'])
            ? status['state']
            : 'unknown',
        if (status['time'] is num) 'timeSeconds': status['time'],
        if (stats is Map) ...{
          for (final key in [
            'decodedvideo',
            'decodedaudio',
            'displayedpictures',
            'playedabuffers',
            'lostpictures',
            'lostabuffers',
          ])
            if (stats[key] is num) key: stats[key],
        },
      };
      return playbackSnapshot(status);
    }

    Future<Map<String, int>> poll({int? seek}) =>
        snapshot(seek: seek).timeout(const Duration(seconds: 5));
    Future<Map<String, int>> waitReady(int target) async {
      final timer = Stopwatch()..start();
      while (timer.elapsed < const Duration(minutes: 2)) {
        try {
          final sample = await poll();
          if (sample['decodedVideo']! > 0 &&
              sample['timeSeconds']! >= target + 1 &&
              sample['timeSeconds']! <= target + 10) {
            return sample;
          }
        } on SocketException {
          // The control listener starts asynchronously with the decoder.
        } on StateError {
          // Input opening precedes the playing state.
        }
        if (server!.failedRequests > 0 || server.budgetExhausted) {
          throw StateError('Media requests failed while opening');
        }
        if (timer.elapsedMilliseconds % 5000 < 600) {
          await reportFile.writeAsString(jsonEncode(report), flush: true);
        }
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
      throw TimeoutException('Decoder failed to reach requested position');
    }

    for (final target in [0, media.duration! ~/ 2, 30]) {
      phase = 'playback at $target seconds';
      final beforeBytes = server.bytesServed;
      final beforeRanges = server.rangeRequests;
      final seekTimer = Stopwatch()..start();
      if (target > 0) await poll(seek: target);
      final first = await waitReady(target);
      final reachedMs = seekTimer.elapsedMilliseconds;
      final timer = Stopwatch()..start();
      final samples = [
        {...first, 'elapsedMs': 0},
      ];
      final window = <String, dynamic>{
        'targetSeconds': target,
        'reachedInMs': reachedMs,
        'startSeconds': first['timeSeconds'],
        'samples': samples,
      };
      (report['windows'] as List).add(window);
      final seconds = target == 0 ? 60 : 15;
      while (timer.elapsed < Duration(seconds: seconds)) {
        await Future<void>.delayed(const Duration(seconds: 1));
        samples.add({...await poll(), 'elapsedMs': timer.elapsedMilliseconds});
        if (samples.length % 10 == 0) {
          await reportFile.writeAsString(jsonEncode(report), flush: true);
        }
      }
      final summary = summarizePlayback(samples);
      window.addAll({
        'endSeconds': samples.last['timeSeconds'],
        ...summary,
        'bytesServed': server.bytesServed - beforeBytes,
        'newRangeRequests': server.rangeRequests - beforeRanges,
      });
      stderr.writeln(
        jsonEncode({
          'status': 'playback-window',
          ...Map.of(window)..remove('samples'),
        }),
      );
      await reportFile.writeAsString(jsonEncode(report), flush: true);
      if (summary['continuousVerified'] != true ||
          summary['audioDecoded'] != true) {
        throw StateError('Playback window failed acceptance');
      }
    }
    if (server.failedRequests != 0) throw StateError('Media requests failed');
    report.addAll({
      'status': 'playback-session-verified',
      'programmaticSeekVerified': true,
      'continuousPlaybackVerified': true,
      'audioDecoded': true,
    });
    return report;
  } catch (_) {
    report.addAll({'status': 'failed', 'phase': phase});
    rethrow;
  } finally {
    client.close(force: true);
    try {
      if (decoder != null) {
        decoder.kill();
        await decoder.exitCode;
        await Future.wait(drains);
      }
    } finally {
      if (server != null) {
        await server.close();
        report.addAll({
          'bytesServed': server.bytesServed,
          'ranges': server.ranges,
          'failedRequests': server.failedRequests,
          'pendingRequestsAfterClose': server.pendingRequests,
        });
      }
      await reportFile.writeAsString(jsonEncode(report), flush: true);
    }
  }
}
