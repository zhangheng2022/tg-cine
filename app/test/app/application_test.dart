import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:tg_cine/app/application.dart';
import 'package:tg_cine/ui/features/home/views/home_view.dart';

import '../support/memory_settings_repository.dart';

void main() {
  testWidgets('compact navigation reveals its label on hover and long press', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      Application(settingsRepository: MemorySettingsRepository()),
    );
    await tester.pumpAndSettle();
    final source = find.bySemanticsLabel('来源').first;
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(source));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('来源'), findsOneWidget);
    await mouse.moveTo(const Offset(790, 850));
    await mouse.removePointer();
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    await tester.longPress(source);
    await tester.pumpAndSettle();
    expect(find.text('来源'), findsOneWidget);
    expect(find.text('还没有影片'), findsOneWidget);
    await tester.tap(source);
    await tester.pumpAndSettle();
    expect(find.text('片库从来源开始'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
  });

  testWidgets('empty library reaches sources, settings, privacy and history', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = MemorySettingsRepository();
    await tester.pumpWidget(Application(settingsRepository: store));
    await tester.pumpAndSettle();
    expect(find.text('还没有影片'), findsOneWidget);
    expect(
      tester.getSize(find.byType(FButton)).height,
      greaterThanOrEqualTo(48),
    );
    await tester.tap(find.text('了解媒体来源'));
    await tester.pumpAndSettle();
    expect(find.text('片库从来源开始'), findsOneWidget);
    await tester.tap(find.text('查看连接状态'));
    await tester.pumpAndSettle();
    expect(find.text('未连接'), findsOneWidget);
    expect(find.text('暂不可用'), findsOneWidget);
    expect(
      tester
          .widget<FBottomNavigationBar>(find.byType(FBottomNavigationBar))
          .index,
      3,
    );
    await tester.tap(find.text('深色'));
    await tester.pumpAndSettle();
    expect(
      tester.element(find.byType(HomeView)).theme.colors.brightness,
      Brightness.dark,
    );
    await tester.ensureVisible(find.text('本机数据说明'));
    await tester.tap(find.text('本机数据说明'));
    await tester.pumpAndSettle();
    expect(find.text('数据留在你手中'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('返回'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('记录'));
    await tester.pumpAndSettle();
    expect(find.text('从第一部影片开始'), findsOneWidget);
    await tester.tap(find.text('返回片库'));
    await tester.pumpAndSettle();
    expect(find.text('还没有影片'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(Application(settingsRepository: store));
    await tester.pumpAndSettle();
    expect(
      tester.element(find.byType(HomeView)).theme.colors.brightness,
      Brightness.dark,
    );
  });

  for (final brightness in Brightness.values) {
    for (final size in [
      const Size(320, 568),
      const Size(800, 900),
      const Size(1440, 900),
    ]) {
      for (final scale in [1.0, 1.3, 2.0]) {
        testWidgets('$size supports $brightness and text scale $scale', (
          tester,
        ) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.platformBrightnessTestValue = brightness;
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(
            tester.platformDispatcher.clearPlatformBrightnessTestValue,
          );
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          await tester.pumpWidget(
            Application(settingsRepository: MemorySettingsRepository()),
          );
          await tester.pumpAndSettle();
          expect(
            tester.element(find.byType(HomeView)).theme.colors.brightness,
            brightness,
          );
          for (final label in ['设置', '记录', '来源', '片库']) {
            final target = find.text(label);
            if (target.evaluate().isNotEmpty) {
              await tester.tap(target.last);
            } else {
              await tester.tap(find.bySemanticsLabel(label));
            }
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          }
          expect(
            find.byType(FBottomNavigationBar),
            size.width < 600 || (size.width < 900 && scale > 1.6)
                ? findsOneWidget
                : findsNothing,
          );
        });
      }
    }
  }
}
