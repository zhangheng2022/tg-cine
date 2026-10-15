import 'package:flutter_test/flutter_test.dart';

import '../../tool/support/playback_stability.dart';

List<Map<String, int>> clocks({
  bool frozenVideo = false,
  bool buffering = false,
  int observedMs = 60000,
}) => [
  for (var elapsed = 0; elapsed <= observedMs; elapsed += 200)
    {
      'elapsedMs': elapsed,
      'positionMs': elapsed,
      'nativeMs': frozenVideo ? elapsed.clamp(0, 1400) : elapsed,
      'audioMs': elapsed,
      'buffering': buffering && elapsed >= 30000 && elapsed < 32000 ? 1 : 0,
      'avSyncMs': 0,
    },
];

void main() {
  test('requires sixty seconds at real speed with continuous UI, native and audio clocks', () {
    expect(summarizePlaybackClocks(clocks())['continuousVerified'], isTrue);
    expect(
      summarizePlaybackClocks(clocks(observedMs: 8000))['continuousVerified'],
      isFalse,
    );
    expect(
      summarizePlaybackClocks(clocks(frozenVideo: true))['continuousVerified'],
      isFalse,
    );
    final buffering = summarizePlaybackClocks(clocks(buffering: true));
    expect(buffering['continuousVerified'], isFalse);
    expect(buffering['bufferingMs'], 2000);
    final slow = clocks()
        .map(
          (sample) => {...sample, 'positionMs': sample['positionMs']! * 2 ~/ 3},
        )
        .toList();
    expect(summarizePlaybackClocks(slow)['continuousVerified'], isFalse);
    final unsynced = clocks();
    unsynced.first['avSyncMs'] = 501;
    expect(summarizePlaybackClocks(unsynced)['continuousVerified'], isFalse);
  });
  test(
    'rejects backwards clocks instead of interpreting a new seek as progress',
    () {
      final samples = clocks();
      samples.last['positionMs'] = 0;
      expect(() => summarizePlaybackClocks(samples), throwsFormatException);
    },
  );
}
