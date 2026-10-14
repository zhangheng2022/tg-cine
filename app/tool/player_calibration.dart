import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:tg_cine/app/application.dart';
import 'package:tg_cine/data/services/playback/media_kit_playback.dart';
import 'package:tg_cine/ui/features/home/views/home_view.dart';
import 'package:tg_cine/ui/features/library/views/library_view.dart';

import 'support/playback_observer.dart';
import 'support/local_media_server.dart';

/// Uses the ordinary Flutter binding and production navigation with local fixtures.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const path = String.fromEnvironment('TG_CINE_CALIBRATION_MEDIA_FILE');
  const output = String.fromEnvironment('TG_CINE_TEST_OUTPUT_DIR');
  const movingFixture = bool.fromEnvironment(
    'TG_CINE_MOVING_FIXTURE',
    defaultValue: true,
  );
  if (!Platform.isWindows || path.isEmpty || output.isEmpty) exit(64);
  final file = File(path);
  if (!await file.exists()) exit(64);
  const throughHttp = bool.fromEnvironment('TG_CINE_CALIBRATION_HTTP');
  LocalMediaServer? server;
  if (throughHttp) {
    final bytes = await file.readAsBytes();
    server = await LocalMediaServer.start(
      size: bytes.length,
      mimeType: 'video/mp4',
      maxBytes: 128 * 1024 * 1024,
      maxRanges: 512,
      read: (offset, count) async => bytes.sublist(offset, offset + count),
    );
  }
  final playback = MediaKitPlayback(
    source: () async => server?.uri ?? file.uri,
  );
  final native = playback.player.platform! as NativePlayer;
  await native.setProperty('mute', 'yes');
  const software = bool.fromEnvironment('TG_CINE_SOFTWARE_OUTPUT');
  const softwareDecode = bool.fromEnvironment('TG_CINE_SOFTWARE_DECODE');
  final controller = VideoController(
    playback.player,
    configuration: software
        ? const VideoControllerConfiguration(
            enableHardwareAcceleration: false,
            hwdec: 'no',
          )
        : VideoControllerConfiguration(hwdec: softwareDecode ? 'no' : null),
  );
  final report = <String, Object?>{
    'status': 'failed',
    'transport': throughHttp ? 'http' : 'file',
    'output': 'flutter-texture',
    'binding': 'WidgetsFlutterBinding',
    'softwareOutput': software,
    'softwareDecode': software || softwareDecode,
    'movingFixture': movingFixture,
  };
  var result = 1;
  try {
    runApp(
      Application(
        playback: playback,
        videoSurface: Video(controller: controller, controls: NoVideoControls),
      ),
    );
    await WidgetsBinding.instance.endOfFrame;
    HomeView? home;
    LibraryView? library;
    void visit(Element element) {
      if (element.widget case final HomeView widget) home = widget;
      if (element.widget case final LibraryView widget) library = widget;
      element.visitChildren(visit);
    }

    visit(WidgetsBinding.instance.rootElement!);
    if (home?.player == null || library?.onOpenPlayer == null) {
      throw StateError('Calibration navigation unavailable');
    }
    library!.onOpenPlayer!();
    await controller.waitUntilFirstFrameRendered.timeout(
      const Duration(seconds: 30),
    );
    final vm = home!.player!;
    final waiting = Stopwatch()..start();
    while ((vm.busy ||
            vm.state.buffering ||
            vm.state.position.inMilliseconds < 500) &&
        waiting.elapsed < const Duration(seconds: 30)) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    if (vm.busy || vm.state.buffering || vm.state.duration.inSeconds < 64) {
      throw StateError('Calibration media unavailable');
    }
    final audio = playback.player.state.tracks.audio.any(
      (track) => track.id != 'auto' && track.id != 'no',
    );
    report['audioSelected'] = audio;
    report['mpvVersion'] = await native.getProperty('mpv-version');
    report['durationMs'] = vm.state.duration.inMilliseconds;
    report['videoWidth'] = playback.player.state.width;
    report['videoHeight'] = playback.player.state.height;
    report['audioSampleRate'] = playback.player.state.audioParams.sampleRate;
    report['startedAt'] = DateTime.now().toUtc().toIso8601String();
    final observation = await observePlayback(
      playback.player,
      () => vm.state.position,
      audioRequired: audio,
    );
    report['observation'] = observation;
    if ((observation['clocks'] as Map)['continuousVerified'] == true &&
        (observation['decodedFrameChanges'] as int) >=
            (movingFixture ? 55 : 1)) {
      report['status'] = 'passed';
      result = 0;
    }
  } catch (_) {
    report['measurementFailed'] = true;
  } finally {
    if (server != null) {
      report['http'] = {
        'bytesServed': server.bytesServed,
        'failedRequests': server.failedRequests,
        'budgetExhausted':
            server.bytesServed >= server.maxBytes ||
            server.ranges.length >= server.maxRanges,
      };
    }
    final destination = File.fromUri(
      Directory(output).uri.resolve('calibration-ordinary-result.json'),
    );
    await destination.parent.create(recursive: true);
    await destination.writeAsString(jsonEncode(report));
    runApp(const SizedBox());
    await WidgetsBinding.instance.endOfFrame;
    await playback.dispose();
    await server?.close();
  }
  exit(result);
}
