import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:tg_cine/app/application.dart';
import 'package:tg_cine/data/repositories/sqlite_media_repository.dart';
import 'package:tg_cine/data/repositories/tdlib_telegram_repository.dart';
import 'package:tg_cine/data/services/telegram/mobile_session.dart';
import 'package:tg_cine/data/services/telegram/windows_session.dart';

import '../test/data/services/telegram/telegram_history_service_test.dart'
    show historyVideo;
import '../test/support/fake_media_library_repository.dart';
import '../test/support/fake_telegram_repository.dart';
import '../test/support/memory_settings_repository.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const outputPath = String.fromEnvironment('TG_CINE_SCREENSHOT_DIR');
  testWidgets(
    'protocol fixture imports through SQLite and Flutter, then restores after restart',
    (tester) async {
      final parent = Platform.isWindows
          ? Directory.systemTemp
          : await getApplicationSupportDirectory();
      final directory = await parent.createTemp('tg-cine-import-acceptance-');
      final keyName =
          'tg-cine.acceptance.import.${DateTime.now().microsecondsSinceEpoch}';
      const vault = FlutterSecureStorage(
        iOptions: IOSOptions(
          accessibility: KeychainAccessibility.first_unlock_this_device,
        ),
      );
      MobileSession? mobile;
      WindowsSession? windows;
      SqliteMediaRepository? store;
      TdlibTelegramRepository? repository;
      final events = StreamController<Map<String, dynamic>>.broadcast();
      final requests = <String>[];
      try {
        if (Platform.isWindows) {
          windows = await WindowsSession.open(
            directory,
            permissionsScript: File(
              const String.fromEnvironment(
                'TG_CINE_PRIVATE_DIRECTORY_SCRIPT',
                defaultValue: 'tool/support/private_directory.ps1',
              ),
            ),
          );
        } else {
          if (Platform.isIOS) {
            await const MethodChannel('io.tgcine/native')
                .invokeMethod<void>('excludeFromBackup', directory.path);
          }
          mobile = await MobileSession.open(directory, vault, keyName: keyName);
        }
        final key = windows?.key ?? mobile!.key;
        final path = p.join(directory.path, 'media.db');
        store = SqliteMediaRepository.open(path, key);
        await store.saveSources(100, {-1});
        final current = store;
        repository = TdlibTelegramRepository(
          () async => TelegramConnection(
            media: current,
            events: events.stream,
            readSources: current.readSources,
            writeSources: current.saveSources,
            close: current.close,
            request: (request) async {
              final type = request['@type'] as String;
              requests.add(type);
              return switch (type) {
                'getAuthorizationState' => {'@type': 'authorizationStateReady'},
                'getMe' => {'@type': 'user', 'id': 100},
                'getChat' => {'@type': 'chat', 'title': '设计数据 · 协议测试来源'},
                'getChats' => {
                  '@type': 'chats',
                  'chat_ids': [-1],
                },
                'searchChatMessages' => {
                  '@type': 'foundChatMessages',
                  'messages': request['from_message_id'] == 0
                      ? [historyVideo(20)]
                      : [historyVideo(20), historyVideo(10, document: true)],
                  'next_from_message_id': request['from_message_id'] == 0
                      ? 19
                      : 0,
                },
                _ => {'@type': 'ok'},
              };
            },
          ),
        );
        await tester.pumpWidget(
          Application(
            settingsRepository: MemorySettingsRepository(),
            telegramRepository: repository,
          ),
        );
        await tester.pumpAndSettle();
        final start = find.byKey(const ValueKey('import--1'));
        await tester.ensureVisible(start);
        await tester.pumpAndSettle();
        await tester.tap(start);
        await tester.pumpAndSettle();
        final deadline = DateTime.now().add(const Duration(seconds: 15));
        while (!(await current.checkpoint(100, -1)).complete &&
            DateTime.now().isBefore(deadline)) {
          await tester.pump(const Duration(milliseconds: 250));
        }
        expect((await current.loadMedia(100)).length, 2);
        expect((await current.checkpoint(100, -1)).complete, isTrue);
        expect(
          requests.where((type) => type == 'searchChatMessages'),
          hasLength(2),
        );
        expect(requests, isNot(contains('downloadFile')));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        await repository.close();
        store = SqliteMediaRepository.open(path, key);
        expect(await store.loadMedia(100), hasLength(2));
        expect((await store.checkpoint(100, -1)).complete, isTrue);
        expect(await store.loadMedia(200), isEmpty);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await repository?.close();
        await store?.close();
        await events.close();
        await mobile?.close();
        await windows?.close();
        if (!Platform.isWindows) await vault.delete(key: keyName);
        final resolved = await directory.resolveSymbolicLinks();
        final base = await parent.resolveSymbolicLinks();
        if (p.dirname(resolved) != base ||
            !p.basename(resolved).startsWith('tg-cine-import-acceptance-')) {
          throw StateError('Unexpected acceptance directory');
        }
        await directory.delete(recursive: true);
      }
    },
    skip: !(Platform.isWindows || Platform.isAndroid || Platform.isIOS),
  );

  testWidgets(
    'capture responsive library and details with labelled design data',
    (tester) async {
      final boundaryKey = GlobalKey();
      for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
        debugDefaultTargetPlatformOverride = platform;
        for (final size in [const Size(390, 844), const Size(1440, 900)]) {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          for (final brightness in Brightness.values) {
            tester.platformDispatcher.platformBrightnessTestValue = brightness;
            for (final scale in [1.0, 2.0]) {
              tester.platformDispatcher.textScaleFactorTestValue = scale;
              final telegram = FakeTelegramRepository(
                restored: true,
                persisted: {-1},
              );
              final library = FakeMediaLibraryRepository();
              await tester.pumpWidget(
                RepaintBoundary(
                  key: boundaryKey,
                  child: Application(
                    key: UniqueKey(),
                    settingsRepository: MemorySettingsRepository(),
                    telegramRepository: telegram,
                    libraryRepository: library,
                  ),
                ),
              );
              await tester.pumpAndSettle();
              Future<void> capture(String state) async {
                final boundary =
                    boundaryKey.currentContext!.findRenderObject()!
                        as RenderRepaintBoundary;
                final image = await boundary.toImage();
                expect(image.width, size.width.toInt());
                expect(image.height, size.height.toInt());
                final bytes = await image.toByteData(
                  format: ui.ImageByteFormat.png,
                );
                image.dispose();
                final file = File(
                  p.join(
                    outputPath,
                    '${size.width < 600 ? 'phone' : 'wide'}-${platform.name}-${brightness.name}-$scale-$state.png',
                  ),
                );
                await file.parent.create(recursive: true);
                await file.writeAsBytes(bytes!.buffer.asUint8List());
              }

              expect(tester.takeException(), isNull);
              await capture('library');
              final item = library.records.first;
              final filename = find.text(item.fileName);
              await tester.ensureVisible(filename);
              await tester.pumpAndSettle();
              await tester.tap(filename);
              await tester.pumpAndSettle();
              expect(tester.takeException(), isNull);
              await capture('details');
              library.linkSupported = false;
              final copy = find.text('复制源消息链接');
              await tester.ensureVisible(copy);
              await tester.pumpAndSettle();
              await tester.tap(copy);
              await tester.pumpAndSettle();
              final unsupported = find.text('这条消息不支持源链接。你仍可在原聊天中查找。');
              await tester.ensureVisible(unsupported);
              await tester.pumpAndSettle();
              expect(unsupported, findsOneWidget);
              expect(tester.takeException(), isNull);
              await capture('link-unsupported');
              await tester.pumpWidget(
                RepaintBoundary(
                  key: boundaryKey,
                  child: Application(
                    key: UniqueKey(),
                    settingsRepository: MemorySettingsRepository(),
                    telegramRepository: FakeTelegramRepository(
                      restored: true,
                      persisted: {-1},
                    ),
                    libraryRepository: FakeMediaLibraryRepository()
                      ..fail = true,
                  ),
                ),
              );
              await tester.pumpAndSettle();
              expect(tester.takeException(), isNull);
              await capture('failure');
              await tester.pumpWidget(const SizedBox());
              await tester.pumpAndSettle();
            }
          }
        }
      }
      debugDefaultTargetPlatformOverride = null;
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearPlatformBrightnessTestValue();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    },
    skip: outputPath.isEmpty,
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
