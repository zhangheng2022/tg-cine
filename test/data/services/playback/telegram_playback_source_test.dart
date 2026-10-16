import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tg_cine/data/services/playback/telegram_playback_source.dart';

import '../telegram/telegram_history_service_test.dart' show historyVideo;

void main() {
  testWidgets(
    'playback source survives five hours and closes only on explicit disposal',
    (tester) async {
      final saved = <Duration>[];
      final clockZone = Zone.current;
      final source = (await tester.runAsync(
        () => runZoned(
          () => TelegramPlaybackSource.start(
            message: historyVideo(10),
            request: (_) async => {'@type': 'ok'},
            checkAccess: () {},
            position: const Duration(seconds: 42),
            savePosition: (
              position, {
              completed = false,
              duration = Duration.zero,
            }) async => saved.add(position),
          ),
          zoneSpecification: ZoneSpecification(
            // Keep socket I/O real while advancing long-lived timers on the test clock.
            createTimer: (self, parent, zone, duration, callback) =>
                duration >= const Duration(hours: 1)
                ? clockZone.createTimer(duration, callback)
                : parent.createTimer(zone, duration, callback),
          ),
        ),
      ))!;
      var closed = false;
      source.closed.then((_) => closed = true);
      try {
        await tester.pump(const Duration(hours: 5));
        expect(closed, isFalse);
        await source.savePosition(const Duration(hours: 5));
        expect(saved.single, const Duration(hours: 5));
      } finally {
        await tester.runAsync(source.close);
        await tester.pump();
      }
      expect(closed, isTrue);
    },
  );
}
