import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../data/services/playback/library_playback.dart';
import '../data/services/playback/media_kit_playback.dart';
import '../domain/models/local_media.dart';
import '../domain/ports/media_playback_repository.dart';
import '../l10n/l10n.dart';
import '../ui/features/player/view_models/player_view_model.dart';
import '../ui/features/player/views/player_view.dart';

class LibraryPlayerPage extends StatefulWidget {
  const LibraryPlayerPage({
    required this.repository,
    required this.media,
    super.key,
  });
  final MediaPlaybackRepository repository;
  final LocalMedia media;

  @override
  State<LibraryPlayerPage> createState() => LibraryPlayerPageState();
}

class LibraryPlayerPageState extends State<LibraryPlayerPage> {
  late final PlayerViewModel _viewModel;
  late final Widget _video;

  Future<void> pause() => _viewModel.leave();

  @override
  void initState() {
    super.initState();
    late MediaKitPlayback native;
    final playback = LibraryPlayback(widget.repository, widget.media, (source) {
      return native = MediaKitPlayback(source: source, separateAudio: true);
    });
    _viewModel = PlayerViewModel(playback);
    _video = Video(
      controller: VideoController(
        native.player,
        // shortcut: Windows hardware decoding stalls; recheck packaged decoders before release.
        configuration: defaultTargetPlatform == TargetPlatform.windows
            ? const VideoControllerConfiguration(hwdec: 'no')
            : const VideoControllerConfiguration(),
      ),
      controls: NoVideoControls,
    );
  }

  @override
  Widget build(BuildContext context) => PlayerView(
    viewModel: _viewModel,
    videoSurface: _video,
    title: widget.media.fileName.isEmpty
        ? context.l10n.libraryUnknownFile
        : widget.media.fileName,
  );

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }
}
