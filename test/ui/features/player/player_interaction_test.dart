import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tg_cine/app/application.dart';

import '../../../support/fake_playback.dart';
import '../../../support/memory_settings_repository.dart';

void main() => playerInteractionTests();

void playerInteractionTests({
  Future<void> Function(WidgetTester, String)? capture,
}) {
  for (final size in [const Size(390, 844), const Size(1440, 900)]) {
    for (final brightness in Brightness.values) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('fullscreen lifecycle $size $brightness $scale', (
          tester,
        ) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
          tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 24);
          addTearDown(tester.view.resetPadding);
          addTearDown(tester.view.resetViewPadding);
          tester.platformDispatcher.platformBrightnessTestValue = brightness;
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(
            tester.platformDispatcher.clearPlatformBrightnessTestValue,
          );
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          final playback = FakePlayback();
          await tester.pumpWidget(
            RepaintBoundary(
              key: const ValueKey('daily-capture'),
              child: Application(
                settingsRepository: MemorySettingsRepository(),
                playback: playback,
                videoSurface: const ColoredBox(
                  color: Color(0xFF173E52),
                  child: Center(
                    child: Text(
                      '设计数据 · 视频画面',
                      style: TextStyle(color: Color(0xFFFFFFFF)),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.text('播放所选视频'));
          await tester.tap(find.text('播放所选视频'));
          await tester.pumpAndSettle();
          await playback.seek(const Duration(minutes: 2));
          await tester.pumpAndSettle();
          final full = find.byKey(const ValueKey('playback-fullscreen'));
          await tester.ensureVisible(full);
          await tester.tap(full);
          await tester.pumpAndSettle();
          final surfaceElement = tester.element(find.text('设计数据 · 视频画面'));
          final name = '${size.width.toInt()}-${brightness.name}-$scale';
          await capture?.call(tester, '$name-fullscreen');
          final hide = find.byKey(const ValueKey('playback-hide-controls'));
          await tester.ensureVisible(hide);
          expect(tester.getSize(hide).height, greaterThanOrEqualTo(48));
          await tester.tap(hide);
          await tester.pumpAndSettle();
          expect(find.byKey(const ValueKey('playback-toggle')), findsNothing);
          await tester.tap(
            find.byKey(const ValueKey('playback-surface-toggle')),
          );
          await tester.pumpAndSettle();
          tester.view.physicalSize = Size(size.height, size.width);
          await tester.pumpAndSettle();
          expect(
            tester.element(find.text('设计数据 · 视频画面')),
            same(surfaceElement),
          );
          expect(playback.opens, 1);
          expect(playback.state.position, const Duration(minutes: 2));
          await capture?.call(tester, '$name-rotated');
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.paused,
          );
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
          expect(playback.state.playing, isFalse);
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.resumed,
          );
          await tester.pumpAndSettle();
          expect(playback.state.playing, isFalse);
          // Escape exits only fullscreen; the page and native player survive.
          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
          await tester.pumpAndSettle();
          expect(
            find.byKey(const ValueKey('playback-fullscreen')),
            findsOneWidget,
          );
          expect(playback.opens, 1);
          await tester.ensureVisible(full);
          await tester.tap(full);
          await tester.pumpAndSettle();
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
          expect(
            find.byKey(const ValueKey('playback-fullscreen')),
            findsOneWidget,
          );
          expect(playback.disposed, isFalse);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
        });
      }
    }
  }
}
