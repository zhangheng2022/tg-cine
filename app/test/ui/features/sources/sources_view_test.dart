import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:tg_cine/app/application.dart';
import 'package:tg_cine/domain/models/telegram_account.dart';

import '../../../support/fake_telegram_repository.dart';
import '../../../support/memory_settings_repository.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final size in [
      const Size(320, 568),
      const Size(800, 900),
      const Size(1440, 900),
    ]) {
      for (final brightness in Brightness.values) {
        for (final scale in [1.0, 2.0]) {
          testWidgets(
            'login and selection support $platform $size $brightness scale $scale',
            (tester) async {
              tester.view.physicalSize = size;
              tester.view.devicePixelRatio = 1;
              tester.platformDispatcher.platformBrightnessTestValue =
                  brightness;
              tester.platformDispatcher.textScaleFactorTestValue = scale;
              addTearDown(tester.view.resetPhysicalSize);
              addTearDown(tester.view.resetDevicePixelRatio);
              addTearDown(
                tester.platformDispatcher.clearPlatformBrightnessTestValue,
              );
              addTearDown(
                tester.platformDispatcher.clearTextScaleFactorTestValue,
              );
              final repository = FakeTelegramRepository();
              await tester.pumpWidget(
                Application(
                  settingsRepository: MemorySettingsRepository(),
                  telegramRepository: repository,
                ),
              );
              await tester.pumpAndSettle();
              await tester.ensureVisible(find.text('了解媒体来源'));
              await tester.tap(find.text('了解媒体来源'));
              await tester.pumpAndSettle();
              expect(find.text('国际格式手机号'), findsOneWidget);
              for (final input in [
                '+12345678901',
                '12345',
                'test-only-password',
              ]) {
                final field = find.byType(EditableText);
                await tester.ensureVisible(field);
                await tester.enterText(field, input);
                final button = find.byKey(
                  const ValueKey('telegram-connect-submit'),
                );
                await tester.ensureVisible(button);
                expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
                await tester.tap(button);
                await tester.pumpAndSettle();
                if (repository.account.stage != TelegramStage.ready) {
                  expect(
                    tester
                        .widget<EditableText>(find.byType(EditableText))
                        .controller
                        .text,
                    isEmpty,
                  );
                  expect(
                    tester
                        .widget<EditableText>(find.byType(EditableText))
                        .obscureText,
                    isTrue,
                  );
                }
              }
              expect(find.text('选择媒体来源'), findsOneWidget);
              final archived = find.byKey(const ValueKey('source--2'));
              await tester.scrollUntilVisible(
                archived,
                120,
                scrollable: find
                    .descendant(
                      of: find.byType(CustomScrollView),
                      matching: find.byType(Scrollable),
                    )
                    .first,
              );
              await tester.pumpAndSettle();
              await tester.tap(archived);
              await tester.pumpAndSettle();
              final private = find.byKey(const ValueKey('source-3'));
              await tester.scrollUntilVisible(
                private,
                120,
                scrollable: find
                    .descendant(
                      of: find.byType(CustomScrollView),
                      matching: find.byType(Scrollable),
                    )
                    .first,
              );
              await tester.pumpAndSettle();
              await tester.tap(private);
              await tester.pumpAndSettle();
              final save = find.byKey(const ValueKey('source-save'));
              await tester.ensureVisible(save);
              await tester.tap(save);
              await tester.pumpAndSettle();
              expect(repository.persisted, {-2, 3});
              expect(find.text('来源选择已保存在本机'), findsOneWidget);
              expect(tester.takeException(), isNull);
              await tester.pumpWidget(const SizedBox());
              await tester.pumpAndSettle();
              expect(repository.closed, isTrue);
              final reopened = FakeTelegramRepository(
                restored: true,
                persisted: repository.persisted,
              );
              await tester.pumpWidget(
                Application(
                  settingsRepository: MemorySettingsRepository(),
                  telegramRepository: reopened,
                ),
              );
              await tester.pumpAndSettle();
              await tester.ensureVisible(find.text('了解媒体来源'));
              await tester.tap(find.text('了解媒体来源'));
              await tester.pumpAndSettle();
              for (final source in ['source--2', 'source-3']) {
                final finder = find.byKey(ValueKey(source));
                await tester.scrollUntilVisible(
                  finder,
                  120,
                  scrollable: find
                      .descendant(
                        of: find.byType(CustomScrollView),
                        matching: find.byType(Scrollable),
                      )
                      .first,
                );
                expect(tester.widget<FCheckbox>(finder).value, isTrue);
              }
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
  testWidgets(
    'search keeps selection; failed save can retry; logout requires confirmation',
    (tester) async {
      final repository = FakeTelegramRepository(restored: true);
      await tester.pumpWidget(
        Application(
          settingsRepository: MemorySettingsRepository(),
          telegramRepository: repository,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('了解媒体来源'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('source--2')));
      await tester.enterText(find.byType(EditableText), '私人');
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('source--2')), findsNothing);
      await tester.tap(find.bySemanticsLabel('记录').first);
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('来源').first);
      await tester.pumpAndSettle();
      expect(
        tester.widget<EditableText>(find.byType(EditableText)).controller.text,
        '私人',
      );
      expect(find.byKey(const ValueKey('source--2')), findsNothing);
      repository.saveFails = true;
      await tester.tap(find.byKey(const ValueKey('source-save')));
      await tester.pumpAndSettle();
      expect(repository.persisted, isEmpty);
      expect(find.text('本机来源记录未能保存或读取，原记录已保留。请重试。'), findsOneWidget);
      repository.saveFails = false;
      await tester.tap(find.byKey(const ValueKey('source-save')));
      await tester.pumpAndSettle();
      expect(repository.persisted, {-2});
      await tester.ensureVisible(find.byKey(const ValueKey('telegram-logout')));
      await tester.tap(find.byKey(const ValueKey('telegram-logout')));
      await tester.pumpAndSettle();
      expect(repository.account.stage, TelegramStage.ready);
      await tester.ensureVisible(find.byKey(const ValueKey('telegram-logout')));
      await tester.tap(find.byKey(const ValueKey('telegram-logout')));
      await tester.pumpAndSettle();
      expect(repository.account.stage, TelegramStage.disconnected);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
}
