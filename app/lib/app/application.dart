import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../data/repositories/local_settings_repository.dart';
import '../domain/models/app_settings.dart';
import '../domain/ports/settings_repository.dart';
import '../domain/ports/playback.dart';
import '../data/services/playback/media_kit_playback.dart';
import '../data/services/playback/development_media_stub.dart'
    if (dart.library.io) '../data/services/playback/development_media_io.dart';
import '../ui/features/player/view_models/player_view_model.dart';
import '../l10n/l10n.dart';
import '../theme/theme.dart';
import '../ui/features/settings/view_models/settings_view_model.dart';
import 'tg_cine_flow.dart';

class Application extends StatefulWidget {
  const Application({
    this.settingsRepository,
    this.playback,
    this.videoSurface,
    super.key,
  });

  final SettingsRepository? settingsRepository;
  final Playback? playback;
  final Widget? videoSurface;

  @override
  State<Application> createState() => _ApplicationState();
}

class _ApplicationState extends State<Application> {
  late final SettingsViewModel _settings;
  PlayerViewModel? _player;
  Widget? _videoSurface;

  @override
  void initState() {
    super.initState();
    _settings = SettingsViewModel(
      widget.settingsRepository ??
          LocalSettingsRepository(SharedPreferencesAsync()),
    );
    unawaited(_settings.load());
    if (widget.playback != null) {
      _player = PlayerViewModel(widget.playback!);
      _videoSurface = widget.videoSurface;
    } else if (kDebugMode &&
        !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.windows) {
      const path = String.fromEnvironment('TG_CINE_DEV_MEDIA_FILE');
      if (path.isNotEmpty) {
        // shortcut: private Windows development source; replace with in-app account/media ports for public builds.
        final playback = MediaKitPlayback(
          source: () => readDevelopmentMedia(path),
          separateAudio: true,
        );
        _player = PlayerViewModel(playback);
        _videoSurface = Video(
          controller: VideoController(
            playback.player,
            // shortcut: Windows hardware decoding stalls here; recheck packaged decoders before release.
            configuration: const VideoControllerConfiguration(hwdec: 'no'),
          ),
          controls: NoVideoControls,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _settings,
    builder: (context, _) => MaterialApp(
      title: 'TG Cine',
      debugShowCheckedModeBanner: false,
      locale: const Locale('zh', 'CN'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        ...FLocalizations.localizationsDelegates,
      ],
      theme: lightTheme.toApproximateMaterialTheme(),
      darkTheme: darkTheme.toApproximateMaterialTheme(),
      themeMode: switch (_settings.appearance) {
        AppAppearance.system => ThemeMode.system,
        AppAppearance.light => ThemeMode.light,
        AppAppearance.dark => ThemeMode.dark,
      },
      builder: (context, child) => FTheme(
        data: Theme.brightnessOf(context) == Brightness.dark
            ? darkTheme
            : lightTheme,
        child: child!,
      ),
      home: TgCineFlow(
        settings: _settings,
        player: _player,
        videoSurface: _videoSurface,
      ),
    ),
  );

  @override
  void dispose() {
    _settings.dispose();
    _player?.dispose();
    super.dispose();
  }
}
