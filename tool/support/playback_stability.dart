import 'dart:math';

/// Millisecond clocks from one uninterrupted window, excluding seek preparation.
Map<String, Object> summarizePlaybackClocks(
  List<Map<String, int>> samples, {
  bool audioRequired = true,
}) {
  if (samples.length < 2) {
    throw const FormatException('Missing playback clocks');
  }
  final clockKeys = ['positionMs', 'nativeMs', if (audioRequired) 'audioMs'];
  final lastAdvance = {
    for (final key in clockKeys) key: samples.first['elapsedMs']!,
  };
  final maxGap = {for (final key in clockKeys) key: 0};
  var bufferingMs = 0;
  var maxAvSyncMs = samples.first['avSyncMs']!.abs();
  for (var index = 1; index < samples.length; index++) {
    final current = samples[index];
    final previous = samples[index - 1];
    final elapsed = current['elapsedMs']!;
    if (elapsed <= previous['elapsedMs']!) {
      throw const FormatException('Non-monotonic sampling time');
    }
    if (previous['buffering'] == 1) {
      bufferingMs += elapsed - previous['elapsedMs']!;
    }
    maxAvSyncMs = max(maxAvSyncMs, current['avSyncMs']!.abs());
    for (final key in clockKeys) {
      if (current[key]! < previous[key]!) {
        throw const FormatException('Playback clock moved backwards');
      }
      maxGap[key] = max(maxGap[key]!, elapsed - lastAdvance[key]!);
      if (current[key]! > previous[key]!) lastAdvance[key] = elapsed;
    }
  }
  final elapsedMs = samples.last['elapsedMs']! - samples.first['elapsedMs']!;
  final advances = {
    for (final key in clockKeys) key: samples.last[key]! - samples.first[key]!,
  };
  return {
    'elapsedMs': elapsedMs,
    'advancedMs': advances,
    'maxNoAdvanceMs': maxGap,
    'bufferingMs': bufferingMs,
    'maxAvSyncMs': maxAvSyncMs,
    'continuousVerified':
        elapsedMs >= 60000 &&
        advances.values.every(
          (advance) =>
              advance >= elapsedMs * 0.98 && advance <= elapsedMs * 1.02,
        ) &&
        maxGap.values.every((gap) => gap <= 1000) &&
        bufferingMs == 0 &&
        (!audioRequired || maxAvSyncMs <= 500),
  };
}
