import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tg_cine/domain/ports/playback.dart';
import 'package:tg_cine/ui/features/player/view_models/player_view_model.dart';

import '../../../support/fake_playback.dart';

void main() {
  test('controls playback, clamps seeks and closes owned resources', () async {
    final playback = FakePlayback();
    final vm = PlayerViewModel(playback);
    await vm.enter();
    expect(vm.state.playing, isTrue);
    await vm.toggle();
    expect(vm.state.playing, isFalse);
    await vm.seek(const Duration(seconds: -10));
    await vm.seek(const Duration(hours: 5));
    expect(playback.seeks, [Duration.zero, const Duration(minutes: 50)]);
    playback.emit(
      const PlaybackState(status: PlaybackStatus.ready, buffering: true),
    );
    expect(vm.state.buffering, isTrue);
    vm.dispose();
    await Future<void>.delayed(Duration.zero);
    expect(playback.disposed, isTrue);
  });
  test('failure is safe and retry can reopen the media', () async {
    final playback = FakePlayback()..failOpen = true;
    final vm = PlayerViewModel(playback);
    await vm.enter();
    expect(vm.state.status, PlaybackStatus.failed);
    expect(vm.busy, isFalse);
    playback.failOpen = false;
    await vm.open();
    expect(vm.state.status, PlaybackStatus.ready);
    playback.failSeek = true;
    await vm.seek(const Duration(seconds: 30));
    expect(vm.state.status, PlaybackStatus.failed);
    vm.dispose();
  });
  test('leaving during loading prevents playback in a hidden route', () async {
    final playback = FakePlayback()..opening = Completer<void>();
    final vm = PlayerViewModel(playback);
    final loading = vm.enter();
    await vm.open();
    expect(playback.opens, 1);
    await vm.leave();
    playback.opening!.complete();
    await loading;
    expect(vm.state.playing, isFalse);
    vm.dispose();
  });
}
