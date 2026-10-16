import 'dart:async';

import 'package:tg_cine/domain/ports/playback.dart';

class FakePlayback implements Playback {
  final controller = StreamController<PlaybackState>.broadcast(sync: true);
  PlaybackState state = const PlaybackState(
    status: PlaybackStatus.ready,
    duration: Duration(minutes: 50),
  );
  bool failOpen = false;
  bool failSeek = false;
  bool disposed = false;
  int opens = 0;
  Duration? openedPosition;
  Completer<void>? opening;
  final seeks = <Duration>[];

  void emit(PlaybackState value) {
    state = value;
    controller.add(value);
  }

  @override
  Stream<PlaybackState> get states => controller.stream;

  @override
  Future<void> open({Duration? position}) async {
    opens++;
    openedPosition = position ?? Duration.zero;
    if (failOpen) throw StateError('private source must not reach UI');
    await opening?.future;
    emit(
      PlaybackState(
        status: PlaybackStatus.ready,
        playing: true,
        position: position ?? Duration.zero,
        duration: state.duration,
      ),
    );
  }

  @override
  Future<void> setPlaying(bool playing) async => emit(
    PlaybackState(
      status: state.status,
      position: state.position,
      duration: state.duration,
      playing: playing,
    ),
  );

  @override
  Future<void> seek(Duration position) async {
    if (failSeek) throw StateError('private native error');
    seeks.add(position);
    emit(
      PlaybackState(
        status: state.status,
        position: position,
        duration: state.duration,
        playing: state.playing,
      ),
    );
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    await controller.close();
  }
}
