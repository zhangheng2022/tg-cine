import 'dart:async';

import '../domain/models/local_media.dart';

import 'package:flutter/widgets.dart';

import '../ui/features/home/view_models/home_view_model.dart';
import '../ui/features/home/views/home_view.dart';
import '../ui/features/settings/view_models/settings_view_model.dart';
import '../ui/features/player/view_models/player_view_model.dart';
import '../ui/features/sources/view_models/sources_view_model.dart';
import '../ui/features/library/view_models/library_view_model.dart';

class TgCineFlow extends StatefulWidget {
  const TgCineFlow({
    required this.settings,
    this.player,
    this.videoSurface,
    this.sources,
    this.library,
    this.onPlayMedia,
    super.key,
  });

  final SettingsViewModel settings;
  final PlayerViewModel? player;
  final Widget? videoSurface;
  final SourcesViewModel? sources;
  final LibraryViewModel? library;
  final FutureOr<void> Function(BuildContext, LocalMedia)? onPlayMedia;

  @override
  State<TgCineFlow> createState() => _TgCineFlowState();
}

class _TgCineFlowState extends State<TgCineFlow> {
  final _viewModel = HomeViewModel();

  @override
  Widget build(BuildContext context) => HomeView(
    viewModel: _viewModel,
    settings: widget.settings,
    player: widget.player,
    videoSurface: widget.videoSurface,
    sources: widget.sources,
    library: widget.library,
    onPlayMedia: widget.onPlayMedia,
  );

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }
}
