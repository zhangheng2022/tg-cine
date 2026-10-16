import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tg_cine/data/services/playback/library_playback.dart';
import 'package:tg_cine/domain/models/local_media.dart';
import 'package:tg_cine/domain/ports/media_playback_repository.dart';
import 'package:tg_cine/domain/ports/playback.dart';

import '../../../support/fake_media_library_repository.dart';
import '../../../support/fake_playback.dart';

class Source implements PlaybackMedia {
  @override
  final uri = Uri.parse('http://127.0.0.1:1234/private');
  @override
  final position = const Duration(seconds: 42);
  final done = Completer<void>();
  final saved = <Duration>[];
  final completions = <bool>[];
  bool failSave = false;
  Completer<void>? saving;
  @override
  Future<void> get closed => done.future;
  @override
  Future<void> close() async {
    if (!done.isCompleted) done.complete();
  }

  @override
  Future<void> savePosition(
    Duration value, {
    bool completed = false,
    Duration duration = Duration.zero,
  }) async {
    if (failSave) throw StateError('private database path');
    await saving?.future;
    saved.add(value);
    completions.add(completed);
  }
}

class Repository implements MediaPlaybackRepository {
  final source = Source();
  Completer<void>? opening;
  @override
  Future<PlaybackMedia> openPlayback(LocalMedia media) async {
    await opening?.future;
    return source;
  }
}

void main() {
  late Repository repository;
  late FakePlayback backend;
  late LibraryPlayback playback;
  setUp(() {
    repository = Repository();
    backend = FakePlayback();
    playback = LibraryPlayback(
      repository,
      FakeMediaLibraryRepository.designMedia.first,
      (_) => backend,
    );
  });
  tearDown(() => playback.dispose());

  test('completion survives pause notifications, seek clears it, unchanged pauses do not retimestamp', () async {
    await playback.open();
    backend.emit(
      const PlaybackState(
        status: PlaybackStatus.ready,
        completed: true,
        position: Duration(minutes: 3),
        duration: Duration(minutes: 3),
      ),
    );
    await Future<void>.delayed(Duration.zero);
    await playback.setPlaying(false);
    expect(repository.source.completions, [true]);
    await playback.seek(const Duration(seconds: 10));
    expect(repository.source.completions.last, isFalse);
    final count = repository.source.saved.length;
    await playback.setPlaying(false);
    await playback.setPlaying(false);
    expect(repository.source.saved.length, count);
  });

  test(
    'opening and closing without playback does not rewrite existing history',
    () async {
      await playback.open();
      await playback.dispose();
      expect(repository.source.saved, isEmpty);
    },
  );

  test('an explicit zero position starts over instead of resuming', () async {
    await playback.open(position: Duration.zero);
    expect(backend.openedPosition, Duration.zero);
    await playback.setPlaying(false);
    expect(repository.source.saved.last, Duration.zero);
  });

  test('periodic saves preserve progress without waiting for exit', () async {
    await playback.open();
    backend.emit(
      const PlaybackState(
        status: PlaybackStatus.ready,
        playing: true,
        position: Duration(seconds: 55),
        duration: Duration(minutes: 3),
      ),
    );
    await Future<void>.delayed(const Duration(seconds: 6));
    expect(repository.source.saved.last, const Duration(seconds: 55));
    await playback.dispose();
  });

  test(
    'opens at saved position; pause, seek and completion persist progress',
    () async {
      await playback.open();
      expect(backend.openedPosition, const Duration(seconds: 42));
      await playback.setPlaying(false);
      expect(repository.source.saved.last, const Duration(seconds: 42));
      await playback.seek(const Duration(seconds: 70));
      expect(repository.source.saved.last, const Duration(seconds: 70));
      await playback.seek(Duration.zero);
      expect(repository.source.saved.last, Duration.zero);
      backend.emit(
        const PlaybackState(
          status: PlaybackStatus.ready,
          completed: true,
          position: Duration(minutes: 3),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(repository.source.saved.last, Duration.zero);
    },
  );

  test(
    'failed opening does not overwrite saved progress and closes the source',
    () async {
      backend.failOpen = true;
      await expectLater(playback.open(), throwsStateError);
      await playback.dispose();
      expect(repository.source.saved, isEmpty);
      expect(repository.source.done.isCompleted, isTrue);
      expect(backend.disposed, isTrue);
    },
  );

  test('disposing while repository opens closes late source without starting decoder', () async {
    repository.opening = Completer();
    final opening = playback.open();
    final closing = playback.dispose();
    repository.opening!.complete();
    await Future.wait([opening, closing]);
    expect(backend.opens, 0);
    expect(repository.source.done.isCompleted, isTrue);
  });

  test(
    'disposing during native open stops decoder after it finishes',
    () async {
      backend.opening = Completer();
      final opening = playback.open();
      await Future<void>.delayed(Duration.zero);
      final closing = playback.dispose();
      backend.opening!.complete();
      await Future.wait([opening, closing]);
      expect(backend.state.playing, isFalse);
      expect(backend.disposed, isTrue);
      expect(repository.source.done.isCompleted, isTrue);
    },
  );

  test(
    'revoking source pauses buffered playback and rejects further play',
    () async {
      final states = <PlaybackState>[];
      final subscription = playback.states.listen(states.add);
      await playback.open();
      await repository.source.close();
      await Future<void>.delayed(Duration.zero);
      expect(backend.state.playing, isFalse);
      expect(states.last.status, PlaybackStatus.failed);
      await expectLater(playback.setPlaying(true), throwsStateError);
      await subscription.cancel();
    },
  );

  test(
    'storage errors are visible and retry without interrupting playback',
    () async {
      final states = <PlaybackState>[];
      final subscription = playback.states.listen(states.add);
      await playback.open();
      repository.source.failSave = true;
      await playback.seek(const Duration(seconds: 50));
      await Future<void>.delayed(Duration.zero);
      expect(states.last.progressFailed, isTrue);
      expect(states.last.status, PlaybackStatus.ready);
      repository.source.failSave = false;
      await playback.setPlaying(false);
      await Future<void>.delayed(Duration.zero);
      expect(states.last.progressFailed, isFalse);
      expect(repository.source.saved.last, const Duration(seconds: 50));
      await subscription.cancel();
    },
  );

  test('slow writes coalesce and disposal waits for latest progress', () async {
    await playback.open();
    repository.source.saving = Completer();
    final first = playback.seek(const Duration(seconds: 50));
    await Future<void>.delayed(Duration.zero);
    final last = playback.seek(const Duration(seconds: 80));
    await Future<void>.delayed(Duration.zero);
    final closing = playback.dispose();
    expect(repository.source.done.isCompleted, isFalse);
    repository.source.saving!.complete();
    await Future.wait([first, last, closing]);
    expect(repository.source.saved.last, const Duration(seconds: 80));
    expect(repository.source.saved.length, 2);
    expect(repository.source.done.isCompleted, isTrue);
  });
}
