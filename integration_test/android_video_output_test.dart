import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:tg_cine/data/services/playback/media_kit_playback.dart';

import 'player_test.dart' show waitFor;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized().framePolicy =
      LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  const sourcePath = String.fromEnvironment('TG_CINE_SILENT_MEDIA_FILE');
  testWidgets(
    'Android configures video output and keeps the video track active',
    (tester) async {
      final file = File(sourcePath);
      expect(await file.exists(), isTrue);
      final playback = MediaKitPlayback(source: () async => file.uri);
      final errors = <String>[];
      final errorSubscription = playback.player.stream.error.listen(errors.add);
      final controller = VideoController(playback.player);
      try {
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Video(controller: controller, controls: NoVideoControls),
          ),
        );
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          await controller.platform.future.timeout(const Duration(seconds: 15));
          await playback.open().timeout(const Duration(seconds: 20));
        });
        await waitFor(
          tester,
          () =>
              playback.player.state.position.inSeconds >= 2 ||
              errors.isNotEmpty,
        );
        expect(errors, isEmpty);
        final native = playback.player.platform! as NativePlayer;
        // Android's first-frame future also completes when only dimensions arrive.
        expect(await native.getProperty('current-vo'), isNotEmpty);
        expect(await native.getProperty('vo-configured'), 'yes');
        expect(await native.getProperty('vid'), isNot('no'));
        expect(await native.getProperty('video-out-params'), isNotEmpty);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(
          () => playback.dispose().timeout(const Duration(seconds: 15)),
        );
        await errorSubscription.cancel();
      }
    },
    skip: !Platform.isAndroid || sourcePath.isEmpty,
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
