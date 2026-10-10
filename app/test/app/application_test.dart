import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:tg_cine/app/application.dart';
import 'package:tg_cine/ui/features/home/views/home_view.dart';

void main() {
  testWidgets('empty-state actions and bottom navigation reach their pages', (
    tester,
  ) async {
    await tester.pumpWidget(const Application());
    await tester.pumpAndSettle();
    expect(find.text('还没有影片'), findsOneWidget);
    expect(
      tester.getSize(find.byType(FButton)).height,
      greaterThanOrEqualTo(48),
    );

    await tester.tap(find.text('前往设置'));
    await tester.pumpAndSettle();
    expect(find.text('账户与连接'), findsOneWidget);
    expect(find.text('未连接'), findsOneWidget);
    expect(find.text('未配置'), findsOneWidget);
    expect(
      tester
          .widget<FBottomNavigationBar>(find.byType(FBottomNavigationBar))
          .index,
      2,
    );

    await tester.tap(find.text('记录'));
    await tester.pumpAndSettle();
    expect(find.text('从第一部影片开始'), findsOneWidget);

    await tester.tap(find.text('返回片库'));
    await tester.pumpAndSettle();
    expect(find.text('还没有影片'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final brightness in Brightness.values) {
    for (final size in [const Size(320, 568), const Size(1280, 720)]) {
      testWidgets('$size supports $brightness and large text', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.platformBrightnessTestValue = brightness;
        tester.platformDispatcher.textScaleFactorTestValue = 1.3;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

        await tester.pumpWidget(const Application());
        await tester.pumpAndSettle();
        final context = tester.element(find.byType(HomeView));
        expect(context.theme.colors.brightness, brightness);

        for (final label in ['设置', '记录', '片库']) {
          await tester.tap(find.text(label).last);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
      });
    }
  }
}
