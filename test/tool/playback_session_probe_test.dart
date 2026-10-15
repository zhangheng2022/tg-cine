import 'package:flutter_test/flutter_test.dart';

import '../../tool/support/playback_session_probe.dart';

void main() {
  Map<String, int> sample(int elapsed, int time, {int? video, int? audio}) => {
    'elapsedMs': elapsed,
    'timeSeconds': time,
    'decodedVideo': video ?? time * 24,
    'decodedAudio': audio ?? time * 48,
    'displayedVideo': time * 24,
    'playedAudio': audio ?? time * 48,
    'lostPictures': 0,
    'lostAudioBuffers': 0,
  };

  test('retains numeric evidence without metadata or control credentials', () {
    final snapshot = playbackSnapshot({
      'time': 20,
      'state': 'playing',
      'information': {'uri': 'private'},
      'stats': {
        'decodedvideo': 200,
        'decodedaudio': 400,
        'displayedpictures': 100,
        'playedabuffers': 200,
        'lostpictures': 0,
        'lostabuffers': 0,
      },
    });
    expect(
      snapshot.keys,
      unorderedEquals([
        'timeSeconds',
        'decodedVideo',
        'decodedAudio',
        'displayedVideo',
        'playedAudio',
        'lostPictures',
        'lostAudioBuffers',
      ]),
    );
    expect(snapshot['decodedAudio'], 400);
    expect(() => playbackSnapshot({'state': 'paused'}), throwsStateError);
    expect(
      () => playbackSnapshot({
        'state': 'playing',
        'time': 0,
        'stats': {
          'decodedvideo': -1,
          'decodedaudio': 0,
          'displayedpictures': 0,
          'playedabuffers': 0,
          'lostpictures': 0,
          'lostabuffers': 0,
        },
      }),
      throwsFormatException,
    );
  });

  test('verifies real time progression with audio and video decoding', () {
    final result = summarizePlayback([
      for (var second = 0; second <= 60; second++)
        sample(second * 1000, 100 + second),
    ]);
    expect(result['continuousVerified'], true);
    expect(result['audioDecoded'], true);
    expect(result['advancedSeconds'], 60);
    expect(result['maximumNoAdvanceMs'], 1000);
  });

  test(
    'rejects buffering followed by a clock jump and reports missing audio',
    () {
      final result = summarizePlayback([
        sample(0, 100, audio: 0),
        for (var second = 1; second <= 7; second++)
          sample(second * 1000, 100, audio: 0),
        sample(8000, 108, audio: 0),
        sample(10000, 110, audio: 0),
      ]);
      expect(result['continuousVerified'], false);
      expect(result['maximumNoAdvanceMs'], 8000);
      expect(result['audioDecoded'], false);
    },
  );

  test(
    'a static decode, faster playback or crossed seek cannot pass continuity',
    () {
      expect(
        summarizePlayback([
          sample(0, 0),
          sample(10000, 10, video: 0),
        ])['continuousVerified'],
        false,
      );
      expect(
        summarizePlayback([
          sample(0, 0),
          sample(10000, 100),
        ])['continuousVerified'],
        false,
      );
      expect(
        () => summarizePlayback([sample(0, 100), sample(1000, 1)]),
        throwsFormatException,
      );
      expect(() => summarizePlayback([sample(0, 0)]), throwsFormatException);
      expect(
        () => summarizePlayback([sample(0, 0), sample(0, 1)]),
        throwsFormatException,
      );
    },
  );

  test('an advancing clock cannot hide frozen video or audio output', () {
    for (final frozen in ['displayedVideo', 'playedAudio']) {
      final samples = [
        for (var second = 0; second <= 15; second++)
          {
            ...sample(second * 1000, second),
            frozen: second < 5 ? second * 20 : 80,
          },
      ];
      final result = summarizePlayback(samples);
      expect(result['continuousVerified'], false);
      expect(
        result[frozen == 'displayedVideo'
            ? 'maximumVideoNoOutputMs'
            : 'maximumAudioNoOutputMs'],
        11000,
      );
    }
  });

  test(
    'predecoded buffers may play continuously while decode counters pause',
    () {
      final samples = [
        for (var second = 0; second <= 15; second++)
          {
            ...sample(second * 1000, 100 + second),
            'decodedVideo': 5000,
            'decodedAudio': 10000,
          },
      ];
      final result = summarizePlayback(samples);
      expect(result['decodedVideoDelta'], 0);
      expect(result['decodedAudioDelta'], 0);
      expect(result['continuousVerified'], true);
    },
  );

  test(
    'dropped pictures or audio buffers fail an otherwise advancing window',
    () {
      for (final counter in ['lostPictures', 'lostAudioBuffers']) {
        final samples = [
          for (var second = 0; second <= 15; second++)
            {...sample(second * 1000, second), counter: second < 10 ? 0 : 1},
        ];
        expect(summarizePlayback(samples)['continuousVerified'], false);
      }
    },
  );
}
