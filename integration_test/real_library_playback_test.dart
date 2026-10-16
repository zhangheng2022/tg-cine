import 'dart:convert';

import 'package:tg_cine/data/services/playback/playback_trace.dart';

import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:tg_cine/app/application.dart';
import 'package:tg_cine/data/repositories/tdlib_telegram_repository.dart';
import 'package:tg_cine/data/services/telegram/windows_telegram.dart';
import 'package:tg_cine/data/services/telegram/tdlib_probe.dart';
import 'package:tg_cine/data/services/relay/relay_bridge.dart';
import 'package:tg_cine/domain/models/local_media.dart';
import 'package:tg_cine/domain/models/telegram_account.dart';
import 'package:tg_cine/domain/ports/playback.dart';
import 'package:tg_cine/ui/features/player/views/player_view.dart';

import '../test/support/memory_settings_repository.dart';
import '../tool/support/playback_observer.dart';
import 'player_test.dart' show waitFor;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized().framePolicy =
      LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  const config = String.fromEnvironment('TG_CINE_REAL_PLAYBACK_CONFIG');
  const selection = String.fromEnvironment('TG_CINE_REAL_PLAYBACK_SELECTION');
  const output = String.fromEnvironment(
    'TG_CINE_TEST_OUTPUT_DIR',
    defaultValue: '.cache/verification',
  );
  testWidgets(
    'real Telegram library audio, slider and restart resume',
    (tester) async {
      final report = <String, Object?>{
        'status': 'failed',
        'stage': 'connect',
        'checks': <Object>[],
      };
      final checks = report['checks'] as List<Object>;
      final requests = <String, Map<String, int>>{};
      report['requests'] = requests;
      final nativeErrors = <String>[];
      report['nativeErrors'] = nativeErrors;
      final downloadWindows = <Map<String, Object?>>[];
      report['downloadWindows'] = downloadWindows;
      final trace = PlaybackTrace();
      Player? currentPlayer;
      final bridges = <RelayBridge>[];
      final outputFile = File('$output/real-library-playback.json');
      late TelegramConnection connection;
      TdlibTelegramRepository create() => TdlibTelegramRepository(
        () async {
          final native = await openWindowsTelegram(
            config,
            defaultService: true,
            onBridgeReady: bridges.add,
          );
          connection = native;
          return TelegramConnection(
            events: native.events,
            readSources: native.readSources,
            writeSources: native.writeSources,
            close: native.close,
            media: native.media,
            revokeRelay: native.revokeRelay,
            waitForLogout: native.waitForLogout,
            request: (request) async {
              if (request['@type'] == 'downloadFile') {
                if (downloadWindows.length < 128) {
                  downloadWindows.add({
                    'stage': report['stage'],
                    'offset': request['offset'],
                    'limit': request['limit'],
                  });
                }
                final bytes =
                    (report['requestedDownloadBytes'] as int? ?? 0) +
                    (request['limit'] as int);
                // Counts requested windows, including overlap; keep a finite test budget.
                if (bytes > 384 * 1024 * 1024) {
                  throw StateError('Verification download budget reached');
                }
                report['requestedDownloadBytes'] = bytes;
                report['downloadRequests'] =
                    (report['downloadRequests'] as int? ?? 0) + 1;
              }
              if (request['@type'] == 'readFilePart') {
                report['readRequests'] =
                    (report['readRequests'] as int? ?? 0) + 1;
              }
              final stats = requests.putIfAbsent(
                request['@type'] as String,
                () => {'count': 0, 'elapsedMs': 0, 'maxMs': 0},
              );
              stats['count'] = stats['count']! + 1;
              final timer = Stopwatch()..start();
              try {
                return await native.request(request);
              } catch (error) {
                final key = error is TdlibRequestError
                    ? 'error${error.code}'
                    : error.runtimeType.toString();
                stats[key] = (stats[key] ?? 0) + 1;
                rethrow;
              } finally {
                final elapsed = timer.elapsedMilliseconds;
                stats['elapsedMs'] = stats['elapsedMs']! + elapsed;
                if (elapsed > stats['maxMs']!) stats['maxMs'] = elapsed;
              }
            },
          );
        },
        defaultService: true,
        playbackTrace: trace,
      );
      var repository = create();
      Future<void> stage(String value) async {
        report['stage'] = value;
        report['trace'] = trace.snapshot();
        report['transport'] = [
          for (final bridge in bridges)
            {
              'activeConnections': bridge.activeConnections,
              'traceIds': bridge.traceIds,
              'connectionFailures': {
                for (final entry in bridge.connectionFailures.entries)
                  '${entry.key}': entry.value,
              },
              'traffic': bridge.traffic.values.toList(),
            },
        ];
        await outputFile.parent.create(recursive: true);
        await outputFile.writeAsString(
          const JsonEncoder.withIndent('  ').convert(report),
        );
      }

      Future<void> mount() async {
        await tester.pumpWidget(
          Application(
            settingsRepository: MemorySettingsRepository(),
            telegramRepository: repository,
          ),
        );
        await waitFor(
          tester,
          () =>
              repository.account.stage != TelegramStage.connecting &&
              repository.account.stage != TelegramStage.disconnected,
          timeout: const Duration(seconds: 90),
        );
        report['authorizationStage'] = repository.account.stage.name;
        if (repository.account.stage != TelegramStage.ready) {
          report['authorizationFailure'] = repository.account.failure?.name;
          throw StateError('Existing Telegram account is not ready');
        }
        await tester.pumpAndSettle();
      }

      Future<void> waitForAudio(Player player) async {
        final native = player.platform! as NativePlayer;
        final waiting = Stopwatch()..start();
        while (double.tryParse(await native.getProperty('audio-pts')) == null) {
          if (waiting.elapsed > const Duration(seconds: 90)) {
            throw StateError('Audio clock did not become ready');
          }
          await tester.pump(const Duration(milliseconds: 200));
        }
      }

      Future<Video> open(LocalMedia item) async {
        final waiting = Stopwatch()..start();
        final resume =
            await connection.media!.loadProgress(
              repository.account.id!,
              item.versionKey,
            ) ??
            Duration.zero;
        final row = find.byKey(ValueKey('media-${item.versionKey}'));
        final files = find
            .descendant(
              of: find.byKey(const PageStorageKey('library-files')),
              matching: find.byType(Scrollable),
            )
            .first;
        await tester.scrollUntilVisible(
          row,
          350,
          scrollable: files,
          maxScrolls: 60,
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(row);
        await tester.tap(row);
        await tester.pumpAndSettle();
        final play = find.byKey(const ValueKey('play-selected-media'));
        await tester.ensureVisible(play);
        await tester.tap(play);
        await tester.pump();
        await waitFor(tester, () => find.byType(Video).evaluate().isNotEmpty);
        final surface = tester.widget<Video>(find.byType(Video));
        currentPlayer = surface.controller.player;
        currentPlayer!.stream.error.listen((error) {
          if (nativeErrors.length >= 16) return;
          // Store only known categories; native text can contain private URLs.
          nativeErrors.add(
            error.contains('403')
                ? 'http403'
                : error.contains('503')
                ? 'http503'
                : error.toLowerCase().contains('timed out')
                ? 'timeout'
                : 'decoder-error',
          );
        });
        await surface.controller.waitUntilFirstFrameRendered.timeout(
          const Duration(seconds: 90),
        );
        final vm = tester.widget<PlayerView>(find.byType(PlayerView)).viewModel;
        await waitFor(
          tester,
          () =>
              vm.state.status == PlaybackStatus.ready &&
              !vm.busy &&
              !vm.state.buffering,
        );
        await waitFor(
          tester,
          () =>
              vm.state.position >= resume + const Duration(seconds: 2) &&
              !vm.state.buffering,
          timeout: const Duration(seconds: 90),
        );
        await waitForAudio(surface.controller.player);
        final waits = (report['openWaitMs'] ??= <int>[]) as List<int>;
        waits.add(waiting.elapsedMilliseconds);
        return surface;
      }

      try {
        await stage('connect');
        await mount();
        final items = await repository.media();
        if (items.isEmpty) throw StateError('Existing library is empty');
        LocalMedia? chosen;
        if (selection.isNotEmpty) {
          final value = jsonDecode(await File(selection).readAsString()) as Map;
          for (final item in items) {
            if (item.sourceId == value['chatId'] &&
                item.messageId == value['messageId']) {
              chosen = item;
            }
          }
        }
        report['selectionMatched'] = chosen != null;
        if (selection.isNotEmpty && chosen == null) {
          throw StateError('Selected media is not in the loaded library');
        }
        chosen ??= items.firstWhere(
          (item) => item.durationSeconds >= 180,
          orElse: () => items.first,
        );
        final item = chosen;
        report['mediaBytes'] = item.sizeBytes;
        await stage('first-frame');
        var surface = await open(item);
        var vm = tester.widget<PlayerView>(find.byType(PlayerView)).viewModel;
        final native = surface.controller.player.platform! as NativePlayer;
        report['firstFrameRendered'] = true;
        report['durationSeconds'] = vm.state.duration.inSeconds;
        // Read native output directly; media_kit can miss the parameter event
        // when the separate audio demuxer replaces the initial track.
        report['audioSampleRate'] = int.tryParse(
          await native.getProperty('audio-params/samplerate'),
        );
        report['audioOutput'] = await native.getProperty('current-ao');
        report['muted'] = await native.getProperty('mute');
        report['volume'] = double.tryParse(await native.getProperty('volume'));
        report['nativeCache'] = {
          for (final property in [
            'demuxer-max-bytes',
            'cache-secs',
            'cache-pause-wait',
            'cache-pause-initial',
            'stream-buffer-size',
          ])
            property: await native.getProperty(property),
        };
        expect(report['muted'], 'no');
        expect(report['audioSampleRate'], greaterThan(0));
        expect(report['audioOutput'], isNot('null'));
        await stage('initial-audio-video');
        checks.add({
          'name': 'initial',
          ...await observePlayback(
            surface.controller.player,
            () => vm.state.position,
          ),
        });
        await stage('slider-forward');
        final slider = find.byKey(const ValueKey('playback-seek'));
        await tester.ensureVisible(slider);
        final track = find.descendant(
          of: slider,
          matching: find.byWidgetPredicate(
            (widget) => widget is Semantics && widget.properties.slider == true,
          ),
        );
        Future<void> dragTo(double fraction) async {
          final thumb = find.descendant(
            of: track,
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is GestureDetector &&
                  widget.onHorizontalDragUpdate != null,
            ),
          );
          final rect = tester.getRect(track);
          final handle = tester.getRect(thumb);
          final destination = Offset(
            rect.left +
                handle.width / 2 +
                (rect.width - handle.width) * fraction,
            rect.center.dy,
          );
          await tester.timedDragFrom(
            handle.center,
            destination - handle.center,
            const Duration(milliseconds: 600),
          );
          await tester.pump();
        }

        await dragTo(0.5);
        final target = vm.state.duration.inMilliseconds ~/ 2;
        await waitFor(
          tester,
          () =>
              !vm.busy &&
              !vm.state.buffering &&
              vm.state.position.inMilliseconds >= target + 2000 &&
              vm.state.position.inMilliseconds < target + 6000,
          timeout: const Duration(seconds: 120),
        );
        report['sliderForwardVerified'] = true;
        await waitForAudio(surface.controller.player);
        await stage('midpoint-audio-video');
        checks.add({
          'name': 'midpoint',
          ...await observePlayback(
            surface.controller.player,
            () => vm.state.position,
          ),
        });
        await stage('slider-backward');
        await dragTo(0.1);
        final back = (vm.state.duration.inMilliseconds * 0.1).round();
        await waitFor(
          tester,
          () =>
              !vm.busy &&
              !vm.state.buffering &&
              vm.state.position.inMilliseconds >= back + 2000 &&
              vm.state.position.inMilliseconds < back + 6000,
          timeout: const Duration(seconds: 120),
        );
        report['sliderBackwardVerified'] = true;
        await waitForAudio(surface.controller.player);
        await stage('backward-audio-video');
        checks.add({
          'name': 'backward',
          ...await observePlayback(
            surface.controller.player,
            () => vm.state.position,
          ),
        });
        await vm.leave();
        final saved = await connection.media!.loadProgress(
          repository.account.id!,
          item.versionKey,
        );
        if (saved == null) throw StateError('Playback progress was not saved');
        report['savedPositionMs'] = saved.inMilliseconds;
        await stage('restart');
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        await repository.close();
        repository = create();
        await mount();
        surface = await open(item);
        vm = tester.widget<PlayerView>(find.byType(PlayerView)).viewModel;
        await waitFor(
          tester,
          () => vm.state.position >= saved && !vm.state.buffering,
        );
        final delta = (vm.state.position - saved).inMilliseconds;
        report['resumeDeltaMs'] = delta;
        report['resumeVerified'] = delta >= 0 && delta < 6000;
        await stage('resume-audio-video');
        checks.add({
          'name': 'resume',
          ...await observePlayback(
            surface.controller.player,
            () => vm.state.position,
          ),
        });
        await vm.leave();
        expect(report['resumeVerified'], isTrue);
        report['status'] =
            checks.every(
              (check) =>
                  ((check as Map)['clocks'] as Map)['continuousVerified'] ==
                  true,
            )
            ? 'passed'
            : 'stability-failed';
        await stage('complete');
        expect(report['status'], 'passed');
      } catch (error) {
        report['errorType'] = error.runtimeType.toString();
        if (find.byType(PlayerView).evaluate().isNotEmpty) {
          final vm = tester
              .widget<PlayerView>(find.byType(PlayerView))
              .viewModel;
          report['playerAtFailure'] = {
            'status': vm.state.status.name,
            'positionMs': vm.state.position.inMilliseconds,
            'buffering': vm.state.buffering,
            'playing': vm.state.playing,
            'busy': vm.busy,
          };
        }
        if (currentPlayer?.platform case final NativePlayer native) {
          report['nativeAtFailure'] = {
            for (final property in [
              'time-pos',
              'audio-pts',
              'pause',
              'paused-for-cache',
              'demuxer-cache-duration',
              'eof-reached',
              'seeking',
            ])
              property: await native.getProperty(property),
          };
        }
        rethrow;
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        await repository.close();
        await stage(report['stage'] as String);
      }
    },
    skip: !Platform.isWindows || config.isEmpty,
    timeout: const Timeout(Duration(minutes: 12)),
  );
}
