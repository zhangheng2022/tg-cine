import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tg_cine/app/application.dart';
import 'package:tg_cine/domain/ports/playback.dart';

import '../../../support/fake_playback.dart';
import '../../../support/memory_settings_repository.dart';

void main() {
  for (final size in [
    const Size(320, 568),
    const Size(800, 900),
    const Size(1440, 900),
  ]) {
    for (final brightness in Brightness.values) {
      for (final scale in [1.0, 2.0]) {
        testWidgets(
          'player supports $size $brightness scale $scale and controls',
          (tester) async {
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1;
            tester.view.padding = const FakeViewPadding(bottom: 34);
            tester.platformDispatcher.platformBrightnessTestValue = brightness;
            tester.platformDispatcher.textScaleFactorTestValue = scale;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            addTearDown(tester.view.resetPadding);
            addTearDown(
              tester.platformDispatcher.clearPlatformBrightnessTestValue,
            );
            addTearDown(
              tester.platformDispatcher.clearTextScaleFactorTestValue,
            );
            final playback = FakePlayback();
            await tester.pumpWidget(
              Application(
                settingsRepository: MemorySettingsRepository(),
                playback: playback,
                videoSurface: const ColoredBox(color: Color(0xFF000000)),
              ),
            );
            await tester.pumpAndSettle();
            await tester.ensureVisible(find.text('播放所选视频'));
            await tester.tap(find.text('播放所选视频'));
            await tester.pumpAndSettle();
            expect(find.text('正在播放'), findsOneWidget);
            final toggle = find.byKey(const ValueKey('playback-toggle'));
            await tester.ensureVisible(toggle);
            await tester.tap(toggle);
            await tester.pumpAndSettle();
            expect(find.text('已暂停'), findsOneWidget);
            await tester.tap(find.bySemanticsLabel('前进 10 秒'));
            await tester.pumpAndSettle();
            expect(playback.seeks.last, const Duration(seconds: 10));
            final slider = find.byKey(const ValueKey('playback-seek'));
            await tester.ensureVisible(slider);
            final track = find.descendant(
              of: slider,
              matching: find.byWidgetPredicate(
                (widget) =>
                    widget is Semantics && widget.properties.slider == true,
              ),
            );
            await tester.tap(track);
            await tester.pumpAndSettle();
            expect(
              playback.seeks.last,
              greaterThan(const Duration(seconds: 10)),
            );
            final thumb = find.descendant(
              of: track,
              matching: find.byWidgetPredicate(
                (widget) =>
                    widget is GestureDetector &&
                    widget.onHorizontalDragUpdate != null,
              ),
            );
            for (final fraction in [0.5, 0.1]) {
              final rect = tester.getRect(track);
              final handle = tester.getRect(thumb);
              final destination = Offset(
                rect.left +
                    handle.width / 2 +
                    (rect.width - handle.width) * fraction,
                rect.center.dy,
              );
              await tester.timedDragFrom(
                handle.center,
                destination - handle.center,
                const Duration(milliseconds: 600),
              );
              await tester.pumpAndSettle();
              expect(
                (playback.seeks.last.inMilliseconds -
                        playback.state.duration.inMilliseconds * fraction)
                    .abs(),
                lessThan(3000),
              );
            }
            playback.emit(const PlaybackState(status: PlaybackStatus.failed));
            await tester.pumpAndSettle();
            await tester.ensureVisible(
              find.byKey(const ValueKey('playback-retry')),
            );
            await tester.tap(find.byKey(const ValueKey('playback-retry')));
            await tester.pumpAndSettle();
            expect(playback.opens, 2);
            expect(tester.takeException(), isNull);
            await tester.tap(find.bySemanticsLabel('返回'));
            await tester.pumpAndSettle();
            expect(playback.state.playing, isFalse);
            await tester.pumpWidget(const SizedBox());
            await tester.pumpAndSettle();
            expect(playback.disposed, isTrue);
          },
        );
      }
    }
  }
}
