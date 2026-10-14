import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:media_kit/media_kit.dart';

import 'playback_stability.dart';

Future<Map<String, Object>> observePlayback(
  Player player,
  Duration Function() position, {
  bool audioRequired = true,
}) async {
  final native = player.platform! as NativePlayer;
  Future<int?> clock(String property) async {
    final value = double.tryParse(await native.getProperty(property));
    if (value == null || !value.isFinite) return null;
    return (value * 1000).round();
  }

  final samples = <Map<String, int>>[];
  final unavailable = <String, int>{};
  var pixels = await player.screenshot();
  var frameSamples = 0;
  var frameChanges = 0;
  var lastFrameMs = -1000;
  final timer = Stopwatch()..start();
  do {
    final nativeMs = await clock('time-pos');
    final audioMs = audioRequired ? await clock('audio-pts') : 0;
    final avSyncMs = audioRequired ? await clock('avsync') : 0;
    final elapsedMs = timer.elapsedMilliseconds;
    final clocks = {
      'nativeMs': nativeMs,
      'audioMs': audioMs,
      'avSyncMs': avSyncMs,
    };
    for (final entry in clocks.entries) {
      if (entry.value == null) {
        unavailable.update(entry.key, (count) => count + 1, ifAbsent: () => 1);
      }
    }
    if (clocks.values.every((value) => value != null)) {
      samples.add({
        'elapsedMs': elapsedMs,
        'positionMs': position().inMilliseconds,
        'nativeMs': nativeMs!,
        'audioMs': audioMs!,
        'avSyncMs': avSyncMs!,
        'buffering': player.state.buffering ? 1 : 0,
        'lifecycle': WidgetsBinding.instance.lifecycleState?.index ?? -1,
        'framesEnabled': WidgetsBinding.instance.framesEnabled ? 1 : 0,
      });
    }
    if (elapsedMs - lastFrameMs >= 1000) {
      final current = await player.screenshot();
      if (current != null && current.isNotEmpty) {
        frameSamples++;
        if (pixels != null && !listEquals(pixels, current)) frameChanges++;
        pixels = current;
      }
      lastFrameMs = elapsedMs;
    }
    await Future<void>.delayed(const Duration(milliseconds: 200));
  } while (timer.elapsed < const Duration(seconds: 61));
  var summary = <String, Object>{'continuousVerified': false};
  if (samples.length >= 2) {
    try {
      summary = summarizePlaybackClocks(samples, audioRequired: audioRequired);
    } on FormatException {
      summary['invalidClockSequence'] = true;
    }
  }
  if (unavailable.isNotEmpty) summary['continuousVerified'] = false;
  return {
    'clocks': summary,
    'unavailableClocks': unavailable,
    'samples': samples,
    'decodedFrameSamples': frameSamples,
    'decodedFrameChanges': frameChanges,
  };
}
