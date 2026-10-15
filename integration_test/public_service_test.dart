import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:tg_cine/app/application.dart';
import 'package:tg_cine/data/services/relay/public_relay_service.dart';
import 'package:tg_cine/domain/models/telegram_account.dart';

import '../test/support/fake_telegram_repository.dart';
import '../test/support/memory_settings_repository.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const outputPath = String.fromEnvironment('TG_CINE_SCREENSHOT_DIR');
  testWidgets(
    'public credential fixture persists in the native vault, refreshes and revokes',
    (tester) async {
      const storage = FlutterSecureStorage();
      const id = '11111111-1111-4111-8111-111111111111';
      final refresh = 'r.$id.${'c' * 43}.${'d' * 43}';
      final access = 'a.$id.${'a' * 43}.${'b' * 43}';
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final origin = Uri.parse('http://127.0.0.1:${server.port}');
      final calls = <String>[];
      server.listen((request) async {
        calls.add(request.uri.path);
        if (request.uri.path != '/v2/devices') {
          expect(request.headers.value('Authorization'), 'Bearer $refresh');
        }
        expect(await utf8.decoder.bind(request).join(), '{}');
        if (request.uri.path == '/v2/devices/revoke') {
          request.response.statusCode = 204;
        } else {
          request.response.statusCode = request.uri.path == '/v2/devices'
              ? 201
              : 200;
          request.response.write(
            jsonEncode({
              'accessToken': access,
              if (request.uri.path == '/v2/devices') 'refreshToken': refresh,
              'expiresAt': DateTime.now()
                  .add(const Duration(minutes: 10))
                  .millisecondsSinceEpoch,
            }),
          );
        }
        await request.response.close();
      });
      var service = PublicRelayService(storage, origin: origin);
      final key = service.credentialKey;
      try {
        expect(await service.accessToken(), access);
        expect(await storage.read(key: key), refresh);
        service.close();
        service = PublicRelayService(storage, origin: origin);
        expect(await service.accessToken(), access);
        expect(calls, ['/v2/devices', '/v2/devices/refresh']);
        await service.revoke();
        expect(await storage.read(key: key), isNull);
        expect(calls.last, '/v2/devices/revoke');
      } finally {
        service.close();
        assert(key.startsWith('tg-cine.public-relay.127.0.0.1.'));
        await storage.delete(key: key);
        await server.close(force: true);
      }
    },
    skip: !(Platform.isWindows || Platform.isAndroid || Platform.isIOS),
  );

  testWidgets(
    'capture default service states with labelled fixture data',
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
              final repository = FakeTelegramRepository(defaultService: true);
              await tester.pumpWidget(
                RepaintBoundary(
                  key: boundaryKey,
                  child: Application(
                    key: UniqueKey(),
                    settingsRepository: MemorySettingsRepository(),
                    telegramRepository: repository,
                  ),
                ),
              );
              await tester.pumpAndSettle();
              await tester.tap(find.byIcon(FLucideIcons.settings).last);
              await tester.pumpAndSettle();
              for (final state in ['connected', 'unavailable', 'renew']) {
                if (state != 'connected') {
                  repository.emit(
                    TelegramAccount(
                      stage: TelegramStage.failed,
                      failure: state == 'renew'
                          ? TelegramFailure.authentication
                          : TelegramFailure.unavailable,
                    ),
                  );
                }
                if (state == 'renew') {
                  await tester.tap(find.byIcon(FLucideIcons.folderOpen).last);
                }
                await tester.pumpAndSettle();
                expect(tester.takeException(), isNull);
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
                final output = File(
                  p.join(
                    outputPath,
                    '${size.width < 600 ? 'phone' : 'wide'}-${platform.name}-${brightness.name}-$scale-$state.png',
                  ),
                );
                await output.parent.create(recursive: true);
                await output.writeAsBytes(bytes!.buffer.asUint8List());
              }
              await tester.pumpWidget(const SizedBox());
              await tester.pumpAndSettle();
            }
          }
        }
      }
      debugDefaultTargetPlatformOverride = null;
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
      tester.platformDispatcher.clearPlatformBrightnessTestValue();
    },
    skip: outputPath.isEmpty,
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
