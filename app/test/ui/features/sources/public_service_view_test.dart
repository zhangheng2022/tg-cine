import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:tg_cine/app/application.dart';
import 'package:tg_cine/domain/models/telegram_account.dart';

import '../../../support/fake_telegram_repository.dart';
import '../../../support/memory_settings_repository.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final size in [const Size(320, 568), const Size(1440, 900)]) {
      for (final brightness in Brightness.values) {
        for (final scale in [1.0, 2.0]) {
          testWidgets(
            'default service states adapt to $platform $size $brightness $scale',
            (tester) async {
              tester.view.physicalSize = size;
              tester.view.devicePixelRatio = 1;
              tester.platformDispatcher.textScaleFactorTestValue = scale;
              tester.platformDispatcher.platformBrightnessTestValue =
                  brightness;
              addTearDown(tester.view.resetPhysicalSize);
              addTearDown(tester.view.resetDevicePixelRatio);
              addTearDown(
                tester.platformDispatcher.clearTextScaleFactorTestValue,
              );
              addTearDown(
                tester.platformDispatcher.clearPlatformBrightnessTestValue,
              );
              final telegram = FakeTelegramRepository(defaultService: true);
              await tester.pumpWidget(
                Application(
                  telegramRepository: telegram,
                  settingsRepository: MemorySettingsRepository(),
                ),
              );
              await tester.pumpAndSettle();
              await tester.tap(find.byIcon(FLucideIcons.settings).last);
              await tester.pumpAndSettle();
              expect(
                find.text('默认服务自动连接。Telegram 登录会话与片库保存在本机，无需填写服务地址或访问令牌。'),
                findsOneWidget,
              );
              expect(find.text('本机开发接入：会话由应用持有；公共默认服务尚未开放。'), findsNothing);
              await tester.ensureVisible(find.text('默认服务'));
              await tester.pumpAndSettle();
              expect(find.text('已连接'), findsOneWidget);
              telegram.emit(
                TelegramAccount(
                  stage: TelegramStage.failed,
                  failure: TelegramFailure.serviceLimited,
                ),
              );
              await tester.pumpAndSettle();
              expect(find.text('暂不可用'), findsOneWidget);
              expect(tester.takeException(), isNull);
              await tester.pumpWidget(const SizedBox());
              await tester.pumpAndSettle();
            },
            variant: TargetPlatformVariant({platform}),
          );
        }
      }
    }
  }
}
