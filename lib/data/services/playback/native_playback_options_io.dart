import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';

Future<void> configureNativePlayback(Player player) async {
  final native = player.platform;
  if (native is NativePlayer) {
    if (Platform.isAndroid &&
        await const MethodChannel('com.alexmercerind/media_kit_video')
                .invokeMethod<bool>('Utils.IsEmulator') ==
            true) {
      // shortcut: avoid zero EGL flags on emulators until bundled libmpv is fixed.
      await native.setProperty('gpu-debug', 'yes');
    }
    // MP4 audio/video small seeks need a byte buffer, separate from the demuxer packet cache.
    await native.setProperty('stream-buffer-size', '${32 * 1024 * 1024}');
    // Disk caching limits packet metadata rather than media bytes.
    await native.setProperty('cache-on-disk', 'no');
    await native.setProperty('cache-secs', '20');
    // Fill both demuxers before playback or a seek crosses cold TDLib ranges.
    await native.setProperty('cache-pause-initial', 'yes');
    await native.setProperty('cache-pause-wait', '20');
    // Cold TDLib ranges can outlast media_kit's five-second HTTP timeout.
    await native.setProperty('network-timeout', '30');
  }
}

Future<void> configureNativeAudio(Player player, Uri source) async {
  if (player.platform is! NativePlayer) return;
  bool hasTrack(Iterable<String> ids) =>
      ids.any((id) => id != 'auto' && id != 'no');
  bool loaded(Tracks tracks) =>
      hasTrack(tracks.video.map((track) => track.id)) ||
      hasTrack(tracks.audio.map((track) => track.id));
  var tracks = player.state.tracks;
  if (!loaded(tracks)) {
    final ready = Completer<Tracks>();
    final subscription = player.stream.tracks.listen(
      (tracks) {
        if (loaded(tracks) && !ready.isCompleted) ready.complete(tracks);
      },
      onDone: () {
        if (!ready.isCompleted) {
          ready.completeError(StateError('Player closed'));
        }
      },
    );
    try {
      tracks = await ready.future.timeout(const Duration(seconds: 30));
    } finally {
      await subscription.cancel();
    }
  }
  if (hasTrack(tracks.audio.map((track) => track.id))) {
    // Separate demuxers keep distant audio/video offsets in independent byte buffers.
    await player.setAudioTrack(
      AudioTrack.uri(source.replace(path: '${source.path}/audio').toString()),
    );
  }
}
