import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:path/path.dart' as p;
import 'package:tg_cine/app/application.dart';
import 'package:tg_cine/data/repositories/sqlite_media_repository.dart';
import 'package:tg_cine/data/repositories/tdlib_telegram_repository.dart';
import 'package:tg_cine/ui/features/player/views/player_view.dart';

import '../test/data/services/telegram/telegram_history_service_test.dart'
    show historyVideo;
import '../test/support/memory_settings_repository.dart';
import 'player_test.dart' show waitFor;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized().framePolicy =
      LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  const path = String.fromEnvironment('TG_CINE_CALIBRATION_MEDIA_FILE');
  testWidgets(
    'library selection decodes local protocol fixture and resumes persisted progress',
    (tester) async {
      final bytes = await File(path).readAsBytes();
      final directory = await Directory.systemTemp.createTemp(
        'tg-cine-playback-',
      );
      final events = StreamController<Map<String, dynamic>>.broadcast();
      final message = historyVideo(10);
      final video = (message['content'] as Map)['video'] as Map;
      video['file_name'] = '播放验收 · 本机合成视频.mp4';
      (video['video'] as Map)['size'] = bytes.length;
      late SqliteMediaRepository store;
      final repository = TdlibTelegramRepository(() async {
        store = SqliteMediaRepository.open(
          '${directory.path}/media.db',
          List.filled(32, 42),
        );
        await store.saveSources(100, {-1});
        final current = store;
        return TelegramConnection(
          media: current,
          events: events.stream,
          readSources: current.readSources,
          writeSources: current.saveSources,
          close: current.close,
          request: (request) async => switch (request['@type']) {
            'getAuthorizationState' => {'@type': 'authorizationStateReady'},
            'getMe' => {'@type': 'user', 'id': 100},
            'getChat' => {'@type': 'chat', 'title': '本机合成测试来源'},
            'getChats' => {
              '@type': 'chats',
              'chat_ids': [-1],
            },
            'searchChatMessages' => {
              '@type': 'foundChatMessages',
              'messages': [message],
              'next_from_message_id': 0,
            },
            'getMessage' => message,
            'getFileDownloadedPrefixSize' => {
              'size': bytes.length - (request['offset'] as int),
            },
            'readFilePart' => {
              'data': base64Encode(
                bytes.sublist(
                  request['offset'] as int,
                  (request['offset'] as int) + (request['count'] as int),
                ),
              ),
            },
            _ => {'@type': 'ok'},
          },
        );
      });
      try {
        await repository.connect();
        await repository.importNext(-1);
        final item = (await repository.media()).single;
        await tester.pumpWidget(
          Application(
            settingsRepository: MemorySettingsRepository(),
            telegramRepository: repository,
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text(item.fileName).first);
        await tester.pumpAndSettle();
        final play = find.byKey(const ValueKey('play-selected-media'));
        await tester.ensureVisible(play);
        await tester.tap(play);
        await tester.pump();
        await waitFor(tester, () => find.byType(Video).evaluate().isNotEmpty);
        var surface = tester.widget<Video>(find.byType(Video));
        await surface.controller.waitUntilFirstFrameRendered.timeout(
          const Duration(seconds: 30),
        );
        var vm = tester.widget<PlayerView>(find.byType(PlayerView)).viewModel;
        await waitFor(
          tester,
          () => vm.state.position.inSeconds >= 2 && !vm.busy,
        );
        await vm.seek(const Duration(seconds: 4));
        await waitFor(
          tester,
          () => vm.state.position.inSeconds >= 4 && !vm.state.buffering,
        );
        await vm.leave();
        final saved = await store.loadProgress(100, item.versionKey);
        expect(saved!.inMilliseconds, greaterThanOrEqualTo(4000));
        Navigator.of(tester.element(find.byType(PlayerView))).pop();
        await tester.pumpAndSettle();
        await tester.ensureVisible(play);
        await tester.tap(play);
        await tester.pump();
        await waitFor(tester, () => find.byType(Video).evaluate().isNotEmpty);
        surface = tester.widget<Video>(find.byType(Video));
        await surface.controller.waitUntilFirstFrameRendered.timeout(
          const Duration(seconds: 30),
        );
        vm = tester.widget<PlayerView>(find.byType(PlayerView)).viewModel;
        await waitFor(tester, () => vm.state.position >= saved && !vm.busy);
        expect(vm.state.position, lessThan(saved + const Duration(seconds: 5)));
        await waitFor(
          tester,
          () => vm.state.position >= saved + const Duration(milliseconds: 500),
        );
        if (surface.controller.player.state.tracks.audio.any(
          (track) => track.id != 'auto' && track.id != 'no',
        )) {
          final native = surface.controller.player.platform! as NativePlayer;
          final audio = double.tryParse(await native.getProperty('audio-pts'));
          expect(audio, isNotNull);
          expect(audio!, greaterThanOrEqualTo(saved.inMilliseconds / 1000));
        }
        expect(
          tester.widget<PlayerView>(find.byType(PlayerView)).title,
          item.fileName,
        );
        expect(tester.takeException(), isNull);
        await vm.leave();
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        await repository.close();
        await events.close();
        final target = await directory.resolveSymbolicLinks();
        final temp = await Directory.systemTemp.resolveSymbolicLinks();
        if (p.dirname(target) != temp ||
            !p.basename(target).startsWith('tg-cine-playback-')) {
          throw StateError('Unexpected test directory');
        }
        await directory.delete(recursive: true);
      }
    },
    skip: path.isEmpty,
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
