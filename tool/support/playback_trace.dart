enum PlaybackStage {
  cacheHit,
  prefixWait,
  windowStart,
  windowComplete,
  windowCancel,
  nativeRead,
  httpQueue,
  httpRead,
  httpFlush,
  rpcPrefix,
  rpcRead,
  rpcDownload,
  rpcCancel,
}

/// Bounded numeric evidence; media identifiers, URLs and native errors are excluded.
class PlaybackTrace {
  final _clock = Stopwatch()..start();
  final _startedAt = DateTime.now().toUtc().toIso8601String();
  final _events = <Map<String, Object>>[];
  final _totals = <PlaybackStage, Map<String, int>>{};
  int _dropped = 0;

  void record(
    PlaybackStage stage, {
    int durationUs = 0,
    int bytes = 0,
    int? offset,
    int? stream,
  }) {
    final total = _totals.putIfAbsent(
      stage,
      () => {'count': 0, 'durationUs': 0, 'maxDurationUs': 0, 'bytes': 0},
    );
    total['count'] = total['count']! + 1;
    total['durationUs'] = total['durationUs']! + durationUs;
    if (durationUs > total['maxDurationUs']!) {
      total['maxDurationUs'] = durationUs;
    }
    total['bytes'] = total['bytes']! + bytes;
    if (_events.length == 4096) {
      _dropped++;
      return;
    }
    _events.add({
      'stage': stage.name,
      'elapsedUs': _clock.elapsedMicroseconds,
      'durationUs': durationUs,
      'bytes': bytes,
      'offset': ?offset,
      'stream': ?stream,
    });
  }

  Map<String, Object> snapshot() => {
    'startedAt': _startedAt,
    'elapsedUs': _clock.elapsedMicroseconds,
    'droppedEvents': _dropped,
    'totals': {
      for (final entry in _totals.entries) entry.key.name: Map.of(entry.value),
    },
    'events': _events.map(Map.of).toList(),
  };
}
