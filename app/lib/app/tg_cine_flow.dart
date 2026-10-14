import 'package:flutter/widgets.dart';

import '../ui/features/home/view_models/home_view_model.dart';
import '../ui/features/home/views/home_view.dart';
import '../ui/features/settings/view_models/settings_view_model.dart';
import '../ui/features/player/view_models/player_view_model.dart';

class TgCineFlow extends StatefulWidget {
  const TgCineFlow({
    required this.settings,
    this.player,
    this.videoSurface,
    super.key,
  });

  final SettingsViewModel settings;
  final PlayerViewModel? player;
  final Widget? videoSurface;

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
  );

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }
}
