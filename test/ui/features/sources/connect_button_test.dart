import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:tg_cine/app/application.dart';
import 'package:tg_cine/domain/models/telegram_account.dart';

import '../../../support/fake_telegram_repository.dart';
import '../../../support/memory_settings_repository.dart';

class _ConnectionRepository extends FakeTelegramRepository {
  _ConnectionRepository() : super(defaultService: true);
  int connects = 0;
  bool reject = false;

  @override
  Future<void> connect() async {
    connects++;
    if (reject) {
      throw const TelegramException(TelegramFailure.unavailable);
    }
    await super.connect();
  }
}

void main() {
  for (final platform in [
    TargetPlatform.windows,
    TargetPlatform.android,
    TargetPlatform.iOS,
  ]) {
    for (final size in [const Size(320, 568), const Size(1440, 900)]) {
      testWidgets(
        'connect button submits, shows failure and retries on $platform $size',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final repository = _ConnectionRepository();
          await tester.pumpWidget(
            Application(
              telegramRepository: repository,
              settingsRepository: MemorySettingsRepository(),
            ),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.byIcon(FLucideIcons.folderOpen).last);
          await tester.pumpAndSettle();
          repository.emit(TelegramAccount(stage: TelegramStage.disconnected));
          await tester.pumpAndSettle();
          final button = find.byKey(const ValueKey('telegram-connect-submit'));
          final initial = repository.connects;
          repository.reject = true;
          await tester.ensureVisible(button);
          await tester.tap(button);
          await tester.pumpAndSettle();
          expect(repository.connects, initial + 1);
          expect(find.text('当前平台的 Telegram 接入尚未就绪。'), findsOneWidget);
          repository.reject = false;
          await tester.ensureVisible(button);
          await tester.tap(button);
          await tester.pumpAndSettle();
          expect(repository.connects, initial + 2);
          expect(find.text('国际格式手机号'), findsOneWidget);
          expect(find.text('当前平台的 Telegram 接入尚未就绪。'), findsNothing);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
        },
        variant: TargetPlatformVariant({platform}),
      );
    }
  }
}
