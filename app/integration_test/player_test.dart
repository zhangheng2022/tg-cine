import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:tg_cine/app/application.dart';
import 'package:tg_cine/data/services/playback/media_kit_playback.dart';
import 'package:tg_cine/data/services/playback/development_media_io.dart';
import 'package:tg_cine/domain/ports/playback.dart';
import 'package:tg_cine/ui/features/player/views/player_view.dart';

import '../test/support/fake_playback.dart';
import '../test/support/memory_settings_repository.dart';
import '../tool/support/local_media_server.dart';
import '../tool/support/playback_observer.dart';

Future<void> waitFor(
  WidgetTester tester,
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 90),
}) async {
  await tester.runAsync(() async {
    final timer = Stopwatch()..start();
    while (!condition() && timer.elapsed < timeout) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
  });
  expect(
    condition(),
    isTrue,
    reason: 'Playback condition did not become ready within the bounded wait',
  );
  await tester.pump();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized().framePolicy =
      LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  const sourcePath = String.fromEnvironment('TG_CINE_DEV_MEDIA_FILE');
  const silentPath = String.fromEnvironment('TG_CINE_SILENT_MEDIA_FILE');
  const calibrationPath = String.fromEnvironment(
    'TG_CINE_CALIBRATION_MEDIA_FILE',
  );
  final outputDirectory = Directory(
    const String.fromEnvironment(
      'TG_CINE_TEST_OUTPUT_DIR',
      defaultValue: '.cache/flutter-player-review',
    ),
  );
  testWidgets(
    'Windows Flutter renders real media and controls playback',
    (tester) async {
      final timer = Stopwatch()..start();
      await tester.pumpWidget(
        Application(settingsRepository: MemorySettingsRepository()),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('播放所选视频'));
      await tester.tap(find.text('播放所选视频'));
      await tester.pump();
      await waitFor(tester, () => find.byType(Video).evaluate().isNotEmpty);
      final video = tester.widget<Video>(find.byType(Video));
      final vm = tester.widget<PlayerView>(find.byType(PlayerView)).viewModel;
      final report = <String, Object?>{
        'status': 'failed',
        'stage': 'first-frame',
      };
      try {
        await video.controller.waitUntilFirstFrameRendered.timeout(
          const Duration(seconds: 90),
        );
        final firstFrameMs = timer.elapsedMilliseconds;
        final byteBuffer =
            await (video.controller.player.platform! as NativePlayer)
                .getProperty('stream-buffer-size');
        expect(int.tryParse(byteBuffer), 32 * 1024 * 1024);
        report.addAll({
          'firstFrameRendered': true,
          'firstFrameMs': firstFrameMs,
          'streamByteBuffer': int.parse(byteBuffer),
          'stage': 'initial-playback',
        });
        await waitFor(
          tester,
          () =>
              vm.state.position >= const Duration(seconds: 3) &&
              !vm.state.buffering,
        );
        final toggle = find.byKey(const ValueKey('playback-toggle'));
        report['stage'] = 'pause';
        await tester.ensureVisible(toggle);
        await tester.tap(toggle);
        await waitFor(tester, () => !vm.state.playing);
        final pausedAt = vm.state.position;
        await Future<void>.delayed(const Duration(seconds: 2));
        await tester.pump();
        expect(
          (vm.state.position - pausedAt).inMilliseconds.abs(),
          lessThan(1000),
        );
        report.addAll({
          'pauseVerified': true,
          'pausedAtMs': pausedAt.inMilliseconds,
          'stage': 'resume',
        });
        await tester.tap(toggle);
        await waitFor(
          tester,
          () =>
              vm.state.playing &&
              vm.state.position > pausedAt + const Duration(seconds: 2),
        );
        report['pauseResumeVerified'] = true;
        report['stage'] = 'seek-30';
        await waitFor(
          tester,
          () => !vm.busy && vm.state.status == PlaybackStatus.ready,
        );
        report['seekCommandReady'] = true;
        await vm.seek(const Duration(seconds: 30));
        await waitFor(
          tester,
          () =>
              vm.state.position >= const Duration(seconds: 30) &&
              vm.state.position < const Duration(seconds: 45) &&
              !vm.state.buffering,
        );
        report['seek30SecondsVerified'] = true;
        report['stage'] = 'backward-control';
        await tester.tap(find.bySemanticsLabel('后退 10 秒'));
        await waitFor(
          tester,
          () =>
              vm.state.position < const Duration(seconds: 27) &&
              vm.state.position >= const Duration(seconds: 18) &&
              !vm.state.buffering,
        );
        final native = video.controller.player.state;
        expect(native.width, greaterThan(0));
        expect(native.height, greaterThan(0));
        expect(native.audioParams.sampleRate, greaterThan(0));
        report.addAll({
          'firstFrameRendered': true,
          'firstFrameMs': firstFrameMs,
          'pauseResumeVerified': true,
          'seek30SecondsVerified': true,
          'backwardControlVerified': true,
          'videoWidth': native.width,
          'videoHeight': native.height,
          'audioSampleRate': native.audioParams.sampleRate,
          'durationSeconds': vm.state.duration.inSeconds,
          'positionSeconds': vm.state.position.inSeconds,
        });
        report['stage'] = 'continuous-seeks';
        final seekChecks = <Map<String, int>>[];
        for (final seconds in [60, 10, 45]) {
          await waitFor(
            tester,
            () => !vm.busy && vm.state.status == PlaybackStatus.ready,
          );
          final seeking = Stopwatch()..start();
          await vm.seek(Duration(seconds: seconds));
          await waitFor(
            tester,
            () =>
                vm.state.playing &&
                !vm.state.buffering &&
                vm.state.position.inMilliseconds >= (seconds + 2) * 1000 &&
                vm.state.position.inMilliseconds < (seconds + 10) * 1000,
          );
          seekChecks.add({
            'targetSeconds': seconds,
            'readyMs': seeking.elapsedMilliseconds,
          });
        }
        report['continuousSeeks'] = seekChecks;
        await tester.tap(find.bySemanticsLabel('返回'));
        await waitFor(tester, () => !vm.state.playing);
        report['leavingPausesPlayback'] = true;
        report['status'] = 'passed';
      } finally {
        final native = video.controller.player.state;
        report.addAll({
          'positionMs': vm.state.position.inMilliseconds,
          'playing': vm.state.playing,
          'buffering': vm.state.buffering,
          'playbackStatus': vm.state.status.name,
          'commandBusy': vm.busy,
          'videoWidth': native.width,
          'videoHeight': native.height,
          'audioSampleRate': native.audioParams.sampleRate,
        });
        final output = File.fromUri(
          outputDirectory.uri.resolve('playback-result.json'),
        );
        await output.parent.create(recursive: true);
        await output.writeAsString(jsonEncode(report));
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 1));
      }
    },
    skip: sourcePath.isEmpty,
    timeout: const Timeout(Duration(minutes: 5)),
  );

  testWidgets(
    'Windows Flutter keeps audio and video advancing after distant seeks',
    (tester) async {
      const decodeOnly = bool.fromEnvironment('TG_CINE_DECODE_ONLY');
      MediaKitPlayback? decoder;
      if (decodeOnly) {
        decoder = MediaKitPlayback(
          source: () => readDevelopmentMedia(sourcePath),
          separateAudio: true,
        );
        addTearDown(decoder.dispose);
        final native = decoder.player.platform! as NativePlayer;
        await native.setProperty('vo', 'null');
        await native.setProperty('vid', 'auto');
        await native.setProperty('mute', 'yes');
      }
      await tester.pumpWidget(
        Application(
          settingsRepository: MemorySettingsRepository(),
          playback: decoder,
          videoSurface: decodeOnly ? const SizedBox() : null,
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('播放所选视频'));
      await tester.tap(find.text('播放所选视频'));
      await tester.pump();
      await waitFor(
        tester,
        () => find.byType(PlayerView).evaluate().isNotEmpty,
      );
      final video = decodeOnly
          ? null
          : tester.widget<Video>(find.byType(Video));
      final player = decoder?.player ?? video!.controller.player;
      final vm = tester.widget<PlayerView>(find.byType(PlayerView)).viewModel;
      final native = player.platform! as NativePlayer;
      final checks = <Map<String, Object?>>[];
      final report = <String, Object?>{
        'status': 'failed',
        'stage': 'first-frame',
        'checks': checks,
        'output': decodeOnly ? 'decoder-only' : 'flutter-texture',
      };
      try {
        debugPrint('Distant playback: first-frame');
        if (video != null) {
          await video.controller.waitUntilFirstFrameRendered.timeout(
            const Duration(seconds: 90),
          );
        }
        await waitFor(
          tester,
          () => !vm.busy && vm.state.position.inSeconds >= 3,
        );
        expect(double.parse(await native.getProperty('network-timeout')), 30);
        if (!decodeOnly) expect(await native.getProperty('hwdec'), 'no');
        var separateAudioSelected = false;
        final trackCount = int.parse(
          await native.getProperty('track-list/count'),
        );
        expect(trackCount, lessThanOrEqualTo(16));
        for (var track = 0; track < trackCount; track++) {
          if (await native.getProperty('track-list/$track/type') == 'audio' &&
              await native.getProperty('track-list/$track/selected') == 'yes' &&
              await native.getProperty('track-list/$track/external') == 'yes') {
            separateAudioSelected = true;
          }
        }
        report['separateAudioSelected'] = separateAudioSelected;
        expect(separateAudioSelected, isTrue);
        const checkpoint = String.fromEnvironment(
          'TG_CINE_SEEK_CHECKPOINT',
          defaultValue: 'midpoint',
        );
        expect(
          [
            'midpoint',
            'midpoint-back',
            'tail',
            'tail-back',
          ].contains(checkpoint),
          isTrue,
        );
        final target = checkpoint.startsWith('tail')
            ? vm.state.duration.inSeconds - 75
            : vm.state.duration.inSeconds ~/ 2;
        expect(target, greaterThan(20));
        final targets = [target, if (checkpoint.endsWith('-back')) target - 10];
        report['startedAt'] = DateTime.now().toUtc().toIso8601String();
        for (final seconds in targets) {
          report['stage'] = 'seek-$seconds';
          debugPrint('Distant playback: seek-$seconds');
          final seeking = Stopwatch()..start();
          await tester.runAsync(
            () => vm
                .seek(Duration(seconds: seconds))
                .timeout(const Duration(seconds: 90)),
          );
          await waitFor(
            tester,
            () =>
                !vm.busy &&
                vm.state.playing &&
                !vm.state.buffering &&
                vm.state.position.inMilliseconds >= (seconds + 2) * 1000 &&
                vm.state.position.inMilliseconds < (seconds + 10) * 1000,
          );
          final check = <String, Object?>{
            'targetSeconds': seconds,
            'readyMs': seeking.elapsedMilliseconds,
          };
          checks.add(check);
          if (seconds != targets.last) {
            check['preparationOnly'] = true;
            continue;
          }
          report['stage'] = 'sustained-$seconds';
          debugPrint('Distant playback: sustained-$seconds');
          final first = await tester.runAsync(() => player.screenshot());
          final observation = await tester.runAsync(
            () => observePlayback(player, () => vm.state.position),
          );
          final last = await tester.runAsync(() => player.screenshot());
          final framesChanged =
              first != null &&
              last != null &&
              first.isNotEmpty &&
              last.isNotEmpty &&
              !listEquals(first, last);
          final stability = observation!['clocks'] as Map;
          check.addAll({
            'stability': stability,
            'observation': observation,
            'framesChanged': framesChanged,
          });
          // Compare pixels in memory; never persist or print private media frames.
          expect(framesChanged, isTrue, reason: 'Video output must change');
          expect(stability['continuousVerified'], isTrue);
        }
        report['status'] = 'passed';
      } finally {
        report.addAll({
          'positionMs': vm.state.position.inMilliseconds,
          'playing': vm.state.playing,
          'buffering': vm.state.buffering,
          'playbackStatus': vm.state.status.name,
          'commandBusy': vm.busy,
        });
        final output = File.fromUri(
          outputDirectory.uri.resolve(
            decodeOnly ? 'distant-decoder-result.json' : 'distant-result.json',
          ),
        );
        await output.parent.create(recursive: true);
        await output.writeAsString(jsonEncode(report));
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 1));
      }
    },
    skip: sourcePath.isEmpty,
    timeout: const Timeout(Duration(minutes: 8)),
  );

  testWidgets(
    'Windows Flutter opens and reopens a silent video without adding an audio source',
    (tester) async {
      final bytes = await File(silentPath).readAsBytes();
      final server = await LocalMediaServer.start(
        size: bytes.length,
        mimeType: 'video/mp4',
        separateStreams: true,
        read: (offset, count) async => bytes.sublist(offset, offset + count),
      );
      addTearDown(server.close);
      final playback = MediaKitPlayback(
        source: () async => server.uri,
        separateAudio: true,
      );
      final controller = VideoController(playback.player);
      await tester.pumpWidget(
        Application(
          settingsRepository: MemorySettingsRepository(),
          playback: playback,
          videoSurface: Video(
            controller: controller,
            controls: NoVideoControls,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('播放所选视频'));
      await tester.tap(find.text('播放所选视频'));
      await tester.pump();
      await waitFor(
        tester,
        () => find.byType(PlayerView).evaluate().isNotEmpty,
      );
      final vm = tester.widget<PlayerView>(find.byType(PlayerView)).viewModel;
      try {
        for (var attempt = 0; attempt < 2; attempt++) {
          if (attempt == 1) await vm.open();
          await waitFor(
            tester,
            () =>
                vm.state.status == PlaybackStatus.ready &&
                !vm.busy &&
                !vm.state.buffering &&
                vm.state.position.inMilliseconds >= 500,
            timeout: const Duration(seconds: 15),
          );
          await controller.waitUntilFirstFrameRendered.timeout(
            const Duration(seconds: 30),
          );
          expect(playback.player.state.width, greaterThan(0));
          final native = playback.player.platform! as NativePlayer;
          expect(await native.getProperty('cache-on-disk'), 'no');
          expect(double.parse(await native.getProperty('cache-secs')), 10);
          expect(double.parse(await native.getProperty('network-timeout')), 30);
          expect(
            int.parse(await native.getProperty('demuxer-max-bytes')),
            8 * 1024 * 1024,
          );
          expect(
            playback.player.state.tracks.audio.any(
              (track) => track.id != 'auto' && track.id != 'no',
            ),
            isFalse,
          );
          expect(vm.state.playing, isTrue);
        }
        expect(server.failedRequests, 0);
        expect(server.ranges.every((range) => range['stream'] == 0), isTrue);
      } finally {
        final native = playback.player.platform! as NativePlayer;
        debugPrint(
          jsonEncode({
            'silentStatus': vm.state.status.name,
            'silentBusy': vm.busy,
            'silentPositionMs': vm.state.position.inMilliseconds,
            'silentDurationMs': vm.state.duration.inMilliseconds,
            'silentPlaying': vm.state.playing,
            'silentBuffering': vm.state.buffering,
            'nativePosition': await native.getProperty('time-pos'),
            'nativeSpeed': await native.getProperty('speed'),
            'nativeFps': await native.getProperty('container-fps'),
            'nativePaused': await native.getProperty('pause'),
            'nativeCachePaused': await native.getProperty('paused-for-cache'),
            'lifecycle': tester.binding.lifecycleState?.name,
            'framesEnabled': tester.binding.framesEnabled,
          }),
        );
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 1));
      }
    },
    skip: silentPath.isEmpty,
    timeout: const Timeout(Duration(minutes: 2)),
  );

  testWidgets(
    'Windows native decoder advances without Flutter texture output',
    (tester) async {
      final playback = MediaKitPlayback(
        source: () async => File(silentPath).uri,
      );
      final native = playback.player.platform! as NativePlayer;
      final report = <String, Object?>{'status': 'failed'};
      try {
        await tester.runAsync(() async {
          await native.setProperty('vo', 'null');
          await native.setProperty('vid', 'auto');
          await playback.open();
          final timer = Stopwatch()..start();
          while (playback.player.state.position.inSeconds < 2 &&
              timer.elapsed < const Duration(seconds: 15)) {
            await Future<void>.delayed(const Duration(milliseconds: 100));
          }
          report.addAll({
            'elapsedMs': timer.elapsedMilliseconds,
            'positionMs': playback.player.state.position.inMilliseconds,
            'durationMs': playback.player.state.duration.inMilliseconds,
            'playing': playback.player.state.playing,
            'buffering': playback.player.state.buffering,
            'output': await native.getProperty('vo'),
            'snapshotAvailable':
                (await playback.player.screenshot())?.isNotEmpty ?? false,
          });
          expect(
            playback.player.state.position.inSeconds,
            greaterThanOrEqualTo(2),
          );
          expect(report['snapshotAvailable'], isTrue);
          report['status'] = 'passed';
        });
      } finally {
        final output = File.fromUri(
          outputDirectory.uri.resolve('decoder-clock.json'),
        );
        await output.parent.create(recursive: true);
        await output.writeAsString(jsonEncode(report));
        await playback.dispose();
      }
    },
    skip: silentPath.isEmpty,
    timeout: const Timeout(Duration(minutes: 1)),
  );

  testWidgets(
    'Windows local calibration sustains sixty seconds of playback',
    (tester) async {
      const throughHttp = bool.fromEnvironment('TG_CINE_CALIBRATION_HTTP');
      const decodeOnly = bool.fromEnvironment('TG_CINE_DECODE_ONLY');
      final file = File(calibrationPath);
      final bytes = throughHttp ? await file.readAsBytes() : null;
      LocalMediaServer? server;
      if (bytes != null) {
        server = await LocalMediaServer.start(
          size: bytes.length,
          mimeType: 'video/mp4',
          read: (offset, count) async => bytes.sublist(offset, offset + count),
        );
        addTearDown(server.close);
      }
      final playback = MediaKitPlayback(
        source: () async => server?.uri ?? file.uri,
      );
      addTearDown(playback.dispose);
      final native = playback.player.platform! as NativePlayer;
      await native.setProperty('mute', 'yes');
      if (decodeOnly) {
        await native.setProperty('vo', 'null');
        await native.setProperty('vid', 'auto');
      }
      final controller = decodeOnly
          ? null
          : VideoController(
              playback.player,
              configuration: const VideoControllerConfiguration(hwdec: 'no'),
            );
      final report = <String, Object?>{
        'status': 'failed',
        'transport': throughHttp ? 'http' : 'file',
        'output': decodeOnly ? 'decoder-only' : 'flutter-texture',
      };
      try {
        await tester.pumpWidget(
          Application(
            settingsRepository: MemorySettingsRepository(),
            playback: playback,
            videoSurface: controller == null
                ? const SizedBox()
                : Video(controller: controller, controls: NoVideoControls),
          ),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('播放所选视频'));
        await tester.tap(find.text('播放所选视频'));
        await tester.pump();
        await waitFor(
          tester,
          () => find.byType(PlayerView).evaluate().isNotEmpty,
        );
        final vm = tester.widget<PlayerView>(find.byType(PlayerView)).viewModel;
        await waitFor(
          tester,
          () =>
              !vm.busy &&
              !vm.state.buffering &&
              vm.state.position.inMilliseconds >= 500,
        );
        if (controller != null) {
          await controller.waitUntilFirstFrameRendered.timeout(
            const Duration(seconds: 30),
          );
        }
        const gatePath = String.fromEnvironment(
          'TG_CINE_CALIBRATION_GATE_FILE',
        );
        if (gatePath.isNotEmpty) {
          expect(decodeOnly, isFalse);
          await vm.toggle();
          await waitFor(tester, () => !vm.state.playing);
          debugPrint(
            'Calibration is paused and waiting for foreground confirmation',
          );
          final gate = File(gatePath);
          await tester.runAsync(() async {
            final waiting = Stopwatch()..start();
            while (!await gate.exists() &&
                waiting.elapsed < const Duration(minutes: 5)) {
              await Future<void>.delayed(const Duration(milliseconds: 250));
            }
          });
          expect(
            await gate.exists(),
            isTrue,
            reason: 'Foreground confirmation was not received',
          );
          await vm.toggle();
          await waitFor(
            tester,
            () => vm.state.playing && vm.state.position.inMilliseconds >= 500,
          );
        }
        expect(vm.state.duration.inSeconds, greaterThanOrEqualTo(64));
        final audio = playback.player.state.tracks.audio.any(
          (track) => track.id != 'auto' && track.id != 'no',
        );
        report['audioSelected'] = audio;
        if (!decodeOnly) {
          expect(await native.getProperty('hwdec'), 'no');
        }
        report['mpvVersion'] = await native.getProperty('mpv-version');
        report['startedAt'] = DateTime.now().toUtc().toIso8601String();
        final observation = await tester.runAsync(
          () => observePlayback(
            playback.player,
            () => vm.state.position,
            audioRequired: audio,
          ),
        );
        report['observation'] = observation;
        expect((observation!['clocks'] as Map)['continuousVerified'], isTrue);
        expect(observation['decodedFrameChanges'], greaterThanOrEqualTo(55));
        report['status'] = 'passed';
      } finally {
        report['lifecycle'] = tester.binding.lifecycleState?.name;
        report['framesEnabled'] = tester.binding.framesEnabled;
        report['positionMs'] = playback.player.state.position.inMilliseconds;
        final output = File.fromUri(
          outputDirectory.uri.resolve('calibration-result.json'),
        );
        await output.parent.create(recursive: true);
        await output.writeAsString(jsonEncode(report));
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 1));
      }
    },
    skip: calibrationPath.isEmpty,
    timeout: const Timeout(Duration(minutes: 8)),
  );
  testWidgets(
    'Windows playback fails safely at quota and retries with a fresh source',
    (tester) async {
      final bytes = await File(calibrationPath).readAsBytes();
      final limited = await LocalMediaServer.start(
        size: bytes.length,
        mimeType: 'video/mp4',
        maxBytes: 1,
        read: (offset, count) async => bytes.sublist(offset, offset + count),
      );
      addTearDown(limited.close);
      final client = HttpClient();
      try {
        final request = await client.getUrl(limited.uri);
        request.headers.set(HttpHeaders.rangeHeader, 'bytes=0-0');
        await (await request.close()).drain<void>();
      } finally {
        client.close(force: true);
      }
      expect(limited.bytesServed, 1);
      final healthy = await LocalMediaServer.start(
        size: bytes.length,
        mimeType: 'video/mp4',
        maxBytes: 128 * 1024 * 1024,
        maxRanges: 512,
        read: (offset, count) async => bytes.sublist(offset, offset + count),
      );
      addTearDown(healthy.close);
      var source = limited.uri;
      final playback = MediaKitPlayback(source: () async => source);
      addTearDown(playback.dispose);
      await (playback.player.platform! as NativePlayer).setProperty(
        'mute',
        'yes',
      );
      final controller = VideoController(
        playback.player,
        configuration: const VideoControllerConfiguration(hwdec: 'no'),
      );
      final report = <String, Object?>{'status': 'failed'};
      try {
        await tester.pumpWidget(
          Application(
            settingsRepository: MemorySettingsRepository(),
            playback: playback,
            videoSurface: Video(
              controller: controller,
              controls: NoVideoControls,
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('播放所选视频'));
        await tester.tap(find.text('播放所选视频'));
        await tester.pump();
        await waitFor(
          tester,
          () => find.byType(PlayerView).evaluate().isNotEmpty,
        );
        final vm = tester.widget<PlayerView>(find.byType(PlayerView)).viewModel;
        await waitFor(
          tester,
          () => vm.state.status == PlaybackStatus.failed && !vm.busy,
          timeout: const Duration(seconds: 45),
        );
        report['quotaFailureVerified'] = true;
        source = healthy.uri;
        await tester.runAsync(vm.open);
        await waitFor(
          tester,
          () =>
              vm.state.status == PlaybackStatus.ready &&
              !vm.busy &&
              !vm.state.buffering &&
              vm.state.position.inSeconds >= 2,
        );
        await controller.waitUntilFirstFrameRendered.timeout(
          const Duration(seconds: 30),
        );
        expect(vm.state.position.inSeconds, lessThan(10));
        expect(playback.player.state.width, greaterThan(0));
        expect(healthy.failedRequests, 0);
        report['freshSourceRetryVerified'] = true;
        report['status'] = 'passed';
      } finally {
        final output = File.fromUri(
          outputDirectory.uri.resolve('recovery-result.json'),
        );
        await output.parent.create(recursive: true);
        await output.writeAsString(jsonEncode(report));
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 1));
      }
    },
    skip: calibrationPath.isEmpty,
    timeout: const Timeout(Duration(minutes: 2)),
  );
  testWidgets(
    'capture native Flutter player layouts without private media pixels',
    (tester) async {
      final key = GlobalKey();
      for (final size in [const Size(390, 844), const Size(1440, 900)]) {
        for (final brightness in Brightness.values) {
          for (final scale in [1.0, 2.0]) {
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1;
            tester.platformDispatcher.platformBrightnessTestValue = brightness;
            tester.platformDispatcher.textScaleFactorTestValue = scale;
            final fake = FakePlayback();
            await tester.pumpWidget(
              RepaintBoundary(
                key: key,
                child: Application(
                  key: UniqueKey(),
                  settingsRepository: MemorySettingsRepository(),
                  playback: fake,
                  videoSurface: const Center(
                    child: Text(
                      '视频画面（布局验收）',
                      style: TextStyle(color: Color(0xFFFFFFFF)),
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            await tester.ensureVisible(find.text('播放所选视频'));
            await tester.tap(find.text('播放所选视频'));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            final boundary =
                key.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final image = await boundary.toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            image.dispose();
            final output = File.fromUri(
              outputDirectory.uri.resolve(
                '${size.width < 600 ? 'phone' : 'wide'}-${brightness.name}-$scale.png',
              ),
            );
            await output.parent.create(recursive: true);
            await output.writeAsBytes(bytes!.buffer.asUint8List());
            await tester.pumpWidget(const SizedBox());
            await tester.pumpAndSettle();
          }
        }
      }
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearPlatformBrightnessTestValue();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    },
  );
}
