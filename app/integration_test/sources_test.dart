import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tg_cine/app/application.dart';
import 'package:tg_cine/domain/models/telegram_account.dart';
import 'package:forui/forui.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:tg_cine/data/repositories/tdlib_telegram_repository.dart';
import 'package:tg_cine/data/services/telegram/windows_telegram.dart';

import '../test/support/fake_telegram_repository.dart';
import '../test/support/memory_settings_repository.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const outputPath = String.fromEnvironment('TG_CINE_SCREENSHOT_DIR');
  const nativeConfig = String.fromEnvironment('TG_CINE_NATIVE_ACCOUNT_CONFIG');

  testWidgets(
    'mobile system vault stores and removes an isolated test record',
    (tester) async {
      const storage = FlutterSecureStorage();
      final key = 'tg-cine.acceptance.${DateTime.now().microsecondsSinceEpoch}';
      expect(await storage.read(key: key), isNull);
      try {
        await storage.write(key: key, value: 'isolated-integration-test');
        expect(await storage.read(key: key), 'isolated-integration-test');
      } finally {
        await storage.delete(key: key);
      }
      expect(await storage.read(key: key), isNull);
    },
    skip: !(Platform.isAndroid || Platform.isIOS),
  );

  testWidgets(
    'authorized native session restores and sources appear in Flutter',
    (tester) async {
      final repository = TdlibTelegramRepository(
        () => openWindowsTelegram(nativeConfig),
      );
      try {
        await tester.pumpWidget(
          Application(
            settingsRepository: MemorySettingsRepository(),
            telegramRepository: repository,
          ),
        );
        final deadline = DateTime.now().add(const Duration(seconds: 60));
        while (repository.account.stage != TelegramStage.ready &&
            DateTime.now().isBefore(deadline)) {
          if (repository.account.stage == TelegramStage.failed) break;
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(repository.account.stage, TelegramStage.ready);
        await tester.tap(find.text('了解媒体来源'));
        while (find.byType(FCheckbox).evaluate().isEmpty &&
            DateTime.now().isBefore(deadline)) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(find.byType(FCheckbox).evaluate().isNotEmpty, isTrue);
        expect(tester.takeException(), isNull);
      } finally {
        await repository.close();
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      }
    },
    skip: !Platform.isWindows || nativeConfig.isEmpty,
    timeout: const Timeout(Duration(minutes: 2)),
  );

  testWidgets(
    'native login, selection and restart using explicit design data',
    (tester) async {
      final persisted = <int>{};
      final repository = FakeTelegramRepository(persisted: persisted);
      await tester.pumpWidget(
        Application(
          settingsRepository: MemorySettingsRepository(),
          telegramRepository: repository,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('了解媒体来源'));
      await tester.pumpAndSettle();
      for (final input in ['+12345678901', '12345', 'test-only-password']) {
        await tester.ensureVisible(find.byType(EditableText));
        await tester.enterText(find.byType(EditableText), input);
        await tester.ensureVisible(
          find.byKey(const ValueKey('telegram-connect-submit')),
        );
        await tester.tap(find.byKey(const ValueKey('telegram-connect-submit')));
        await tester.pumpAndSettle();
      }
      final source = find.byKey(const ValueKey('source--2'));
      await tester.scrollUntilVisible(
        source,
        100,
        scrollable: find
            .descendant(
              of: find.byType(CustomScrollView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(source);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('source-save')));
      await tester.pumpAndSettle();
      expect(persisted, {-2});
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      final reopened = FakeTelegramRepository(
        restored: true,
        persisted: persisted,
      );
      await tester.pumpWidget(
        Application(
          settingsRepository: MemorySettingsRepository(),
          telegramRepository: reopened,
        ),
      );
      await tester.pumpAndSettle();
      expect(reopened.account.selectedSources, {-2});
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'capture Flutter login and source layouts with no private data',
    (tester) async {
      final boundaryKey = GlobalKey();
      for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
        debugDefaultTargetPlatformOverride = platform;
        for (final size in [const Size(390, 844), const Size(1440, 900)]) {
          for (final brightness in Brightness.values) {
            for (final scale in [1.0, 2.0]) {
              tester.view.physicalSize = size;
              tester.view.devicePixelRatio = 1;
              tester.platformDispatcher.platformBrightnessTestValue =
                  brightness;
              tester.platformDispatcher.textScaleFactorTestValue = scale;
              for (final ready in [false, true]) {
                final repository = FakeTelegramRepository(
                  restored: ready,
                  persisted: ready ? {-2} : {},
                );
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
                await tester.ensureVisible(find.text('了解媒体来源'));
                await tester.tap(find.text('了解媒体来源'));
                await tester.pumpAndSettle();
                if (!ready && brightness == Brightness.dark) {
                  repository.emit(
                    TelegramAccount(stage: TelegramStage.password),
                  );
                  await tester.pumpAndSettle();
                }
                expect(tester.takeException(), isNull);
                final boundary =
                    boundaryKey.currentContext!.findRenderObject()!
                        as RenderRepaintBoundary;
                final image = await boundary.toImage();
                final bytes = await image.toByteData(
                  format: ui.ImageByteFormat.png,
                );
                image.dispose();
                final output = File.fromUri(
                  Directory(outputPath).uri.resolve(
                    '${size.width < 600 ? 'phone' : 'wide'}-${platform.name}-${brightness.name}-$scale-${ready ? 'sources' : 'login'}.png',
                  ),
                );
                await output.parent.create(recursive: true);
                await output.writeAsBytes(bytes!.buffer.asUint8List());
                await tester.pumpWidget(const SizedBox());
                await tester.pumpAndSettle();
              }
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
