import 'dart:async';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:forui/forui.dart';

import '../../../../domain/ports/playback.dart';
import '../../../../l10n/l10n.dart';
import '../view_models/player_view_model.dart';

String playbackTime(Duration duration) {
  final seconds = max(0, duration.inSeconds);
  final minutes = seconds ~/ 60;
  return '${minutes.toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
}

class PlayerView extends StatefulWidget {
  const PlayerView({
    required this.viewModel,
    required this.videoSurface,
    this.title,
    this.development = false,
    super.key,
  });

  final PlayerViewModel viewModel;
  final Widget videoSurface;
  final String? title;
  final bool development;

  @override
  State<PlayerView> createState() => _PlayerViewState();
}

class _PlayerViewState extends State<PlayerView> with WidgetsBindingObserver {
  double? _seeking;
  bool _fullscreen = false;
  bool _controlsVisible = true;
  final _surfaceKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(widget.viewModel.enter());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(widget.viewModel.enter());
    }
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      unawaited(widget.viewModel.leave());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(widget.viewModel.leave());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_fullscreen,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop && _fullscreen) setState(() => _fullscreen = false);
    },
    child: CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (_fullscreen) setState(() => _fullscreen = false);
        },
      },
      child: ListenableBuilder(
        listenable: widget.viewModel,
        builder: (context, _) {
          final l10n = context.l10n;
          if (_fullscreen) return _fullscreenView(context);
          return FScaffold(
            header: FHeader.nested(
              title: Text(
                widget.title ?? l10n.selectedVideo,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              prefixes: [
                SizedBox(
                  width: 48,
                  height: 48,
                  child: FButton.icon(
                    variant: FButtonVariant.ghost,
                    semanticsLabel: l10n.back,
                    onPress: () => Navigator.of(context).pop(),
                    child: const Icon(FLucideIcons.arrowLeft),
                  ),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1080),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 16,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SizedBox(
                              height: min(
                                constraints.maxWidth * 9 / 16,
                                max(
                                  140,
                                  constraints.maxHeight *
                                      (MediaQuery.textScalerOf(context)
                                                  .scale(16) >
                                              25
                                          ? 0.38
                                          : 0.52),
                                ),
                              ),
                              child: ColoredBox(
                                color: const Color(0xFF000000),
                                child: KeyedSubtree(
                                  key: _surfaceKey,
                                  child: widget.videoSurface,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            _controls(context),
                            const SizedBox(height: 12),
                            ConstrainedBox(
                              constraints: const BoxConstraints(minHeight: 48),
                              child: FButton(
                                key: const ValueKey('playback-fullscreen'),
                                variant: FButtonVariant.outline,
                                onPress: () =>
                                    setState(() => _fullscreen = true),
                                child: Text(l10n.playbackFullscreen),
                              ),
                            ),
                            if (widget.development) ...[
                              const SizedBox(height: 24),
                              Text(
                                l10n.developmentPlaybackNotice,
                                style: context.theme.typography.body.sm
                                    .copyWith(
                                      color:
                                          context.theme.colors.mutedForeground,
                                    ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    ),
  );

  Widget _controls(BuildContext context) {
    final l10n = context.l10n;
    final state = widget.viewModel.state;
    final ready = state.status == PlaybackStatus.ready;
    final enabled = ready && !widget.viewModel.busy;
    final duration = state.duration.inMilliseconds;
    final progress =
        _seeking ??
        (duration > 0
            ? (state.position.inMilliseconds / duration).clamp(0.0, 1.0)
            : 0.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          switch (state.status) {
            PlaybackStatus.failed => l10n.playbackError,
            PlaybackStatus.idle ||
            PlaybackStatus.loading => l10n.playbackLoading,
            PlaybackStatus.ready when state.buffering => l10n.playbackBuffering,
            PlaybackStatus.ready when state.completed => l10n.playbackCompleted,
            PlaybackStatus.ready =>
              state.playing ? l10n.playbackPlaying : l10n.playbackPaused,
          },
          style: context.theme.typography.body.md,
          key: const ValueKey('playback-status'),
        ),
        const SizedBox(height: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: FSlider(
            key: const ValueKey('playback-seek'),
            label: Text(l10n.playbackProgress),
            enabled: enabled && duration > 0,
            trackHitRegionCrossExtent: 48,
            control: FSliderControl.liftedContinuous(
              value: FSliderValue(max: progress),
              onChange: (value) => setState(() => _seeking = value.max),
            ),
            onEnd: (value) {
              final target = _seeking ?? value.max;
              setState(() => _seeking = null);
              unawaited(
                widget.viewModel.seek(
                  Duration(milliseconds: (target * duration).round()),
                ),
              );
            },
            tooltipBuilder: (_, value) => Text(
              playbackTime(Duration(milliseconds: (value * duration).round())),
            ),
            semanticValueFormatterCallback: (value) => playbackTime(
              Duration(milliseconds: (value * duration).round()),
            ),
          ),
        ),
        Text(
          '${playbackTime(state.position)} / ${playbackTime(state.duration)}',
          style: context.theme.typography.body.sm,
        ),
        const SizedBox(height: 16),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Row(
              children: [
                SizedBox(
                  width: 48,
                  height: 48,
                  child: FButton.icon(
                    variant: FButtonVariant.outline,
                    semanticsLabel: l10n.playbackBackward,
                    onPress: enabled
                        ? () => unawaited(
                            widget.viewModel.seek(
                              state.position - const Duration(seconds: 10),
                            ),
                          )
                        : null,
                    child: const Icon(FLucideIcons.rotateCcw),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 48),
                    child: FButton(
                      key: const ValueKey('playback-toggle'),
                      onPress: enabled
                          ? () => unawaited(widget.viewModel.toggle())
                          : null,
                      child: Text(
                        state.completed
                            ? l10n.playbackReplay
                            : state.playing
                            ? l10n.playbackPause
                            : l10n.playbackPlay,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 48,
                  height: 48,
                  child: FButton.icon(
                    variant: FButtonVariant.outline,
                    semanticsLabel: l10n.playbackForward,
                    onPress: enabled
                        ? () => unawaited(
                            widget.viewModel.seek(
                              state.position + const Duration(seconds: 10),
                            ),
                          )
                        : null,
                    child: const Icon(FLucideIcons.rotateCw),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (state.progressFailed)
          Semantics(liveRegion: true, child: Text(l10n.playbackProgressError)),
        if (state.status == PlaybackStatus.failed) ...[
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: FButton(
              key: const ValueKey('playback-retry'),
              onPress: widget.viewModel.busy
                  ? null
                  : () => unawaited(widget.viewModel.open()),
              child: Text(l10n.retry),
            ),
          ),
        ],
      ],
    );
  }

  Widget _fullscreenView(BuildContext context) {
    final l = context.l10n;
    final state = widget.viewModel.state;
    final visible =
        _controlsVisible ||
        !state.playing ||
        state.buffering ||
        state.status != PlaybackStatus.ready ||
        state.completed;
    return Focus(
      autofocus: true,
      child: ColoredBox(
        color: const Color(0xFF000000),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => Stack(
              fit: StackFit.expand,
              children: [
                KeyedSubtree(key: _surfaceKey, child: widget.videoSurface),
                Semantics(
                  button: true,
                  label: l.playbackShowControls,
                  child: GestureDetector(
                    key: const ValueKey('playback-surface-toggle'),
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(() => _controlsVisible = !visible),
                  ),
                ),
                if (visible)
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: 1080,
                        maxHeight: constraints.maxHeight * 0.85,
                      ),
                      child: ColoredBox(
                        color: context.theme.colors.background.withValues(
                          alpha: 0.94,
                        ),
                        child: SingleChildScrollView(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        minHeight: 48,
                                      ),
                                      child: FButton(
                                        mainAxisSize: MainAxisSize.min,
                                        builder: (_, _, _, _, _, child) =>
                                            Flexible(child: child!),
                                        key: const ValueKey(
                                          'playback-exit-fullscreen',
                                        ),
                                        variant: FButtonVariant.outline,
                                        onPress: () =>
                                            setState(() => _fullscreen = false),
                                        child: Text(l.playbackExitFullscreen),
                                      ),
                                    ),
                                    ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        minHeight: 48,
                                      ),
                                      child: FButton(
                                        mainAxisSize: MainAxisSize.min,
                                        builder: (_, _, _, _, _, child) =>
                                            Flexible(child: child!),
                                        key: const ValueKey(
                                          'playback-hide-controls',
                                        ),
                                        variant: FButtonVariant.outline,
                                        onPress:
                                            state.playing &&
                                                !state.buffering &&
                                                state.status ==
                                                    PlaybackStatus.ready &&
                                                !state.completed
                                            ? () => setState(
                                                () => _controlsVisible = false,
                                              )
                                            : null,
                                        child: Text(l.playbackHideControls),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                _controls(context),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
