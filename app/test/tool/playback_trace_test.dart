import 'package:flutter_test/flutter_test.dart';

import '../../tool/support/playback_trace.dart';

void main() {
  test(
    'trace stays bounded while retaining totals and returns detached data',
    () {
      final trace = PlaybackTrace();
      for (var index = 0; index < 4097; index++) {
        trace.record(
          PlaybackStage.httpRead,
          durationUs: index,
          bytes: 2,
          offset: index,
          stream: 1,
        );
      }
      final report = trace.snapshot();
      expect(report['droppedEvents'], 1);
      expect(report['events'], hasLength(4096));
      final totals = report['totals'] as Map;
      final reads = totals['httpRead'] as Map;
      expect(reads['count'], 4097);
      expect(reads['bytes'], 8194);
      expect(reads['maxDurationUs'], 4096);
      reads.clear();
      (report['events'] as List).clear();
      expect(trace.snapshot()['events'], hasLength(4096));
      expect(
        ((trace.snapshot()['totals'] as Map)['httpRead'] as Map)['count'],
        4097,
      );
    },
  );
}
