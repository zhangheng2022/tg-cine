import 'package:flutter/widgets.dart';
import 'package:material_ui/material_ui.dart' show MaterialPageRoute;
import 'package:forui/forui.dart';

import '../../../../l10n/l10n.dart';
import '../../history/views/history_view.dart';
import '../../library/views/library_view.dart';
import '../../settings/view_models/settings_view_model.dart';
import '../../settings/views/settings_view.dart';
import '../../sources/views/sources_view.dart';
import '../view_models/home_view_model.dart';
import '../../player/view_models/player_view_model.dart';
import '../../player/views/player_view.dart';

class HomeView extends StatelessWidget {
  const HomeView({
    required this.viewModel,
    required this.settings,
    this.player,
    this.videoSurface,
    super.key,
  });

  final HomeViewModel viewModel;
  final SettingsViewModel settings;
  final PlayerViewModel? player;
  final Widget? videoSurface;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: viewModel,
    builder: (context, _) => LayoutBuilder(
      builder: (context, constraints) {
        final l10n = context.l10n;
        final largeText = MediaQuery.textScalerOf(context).scale(16) / 16;
        final bottomNavigation =
            constraints.maxWidth < 600 ||
            (constraints.maxWidth < 900 && largeText > 1.6);
        final expandedSidebar = constraints.maxWidth >= 1024;
        final labels = [
          l10n.libraryTab,
          l10n.historyTab,
          l10n.sourcesTitle,
          l10n.settingsTitle,
        ];
        const icons = [
          FLucideIcons.film,
          FLucideIcons.history,
          FLucideIcons.folderOpen,
          FLucideIcons.settings,
        ];
        final content = FScaffold(
          header: FHeader(
            title: Text(switch (viewModel.selectedTab) {
              HomeTab.library => l10n.appName,
              HomeTab.history => l10n.historyTitle,
              HomeTab.sources => l10n.sourcesTitle,
              HomeTab.settings => l10n.settingsTitle,
            }),
          ),
          footer: bottomNavigation
              ? FBottomNavigationBar(
                  index: viewModel.selectedTab.index,
                  safeAreaBottom: true,
                  onChange: (index) => viewModel.select(HomeTab.values[index]),
                  children: [
                    for (var index = 0; index < labels.length; index++)
                      FBottomNavigationBarItem(
                        icon: Icon(icons[index]),
                        label: Text(labels[index]),
                      ),
                  ],
                )
              : null,
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1080),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: bottomNavigation ? 8 : 20,
                ),
                child: switch (viewModel.selectedTab) {
                  HomeTab.library => LibraryView(
                    onOpenSources: () => viewModel.select(HomeTab.sources),
                    onOpenPlayer: player != null && videoSurface != null
                        ? () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => PlayerView(
                                viewModel: player!,
                                videoSurface: videoSurface!,
                              ),
                            ),
                          )
                        : null,
                  ),
                  HomeTab.history => HistoryView(
                    onOpenLibrary: () => viewModel.select(HomeTab.library),
                  ),
                  HomeTab.sources => SourcesView(
                    onOpenSettings: () => viewModel.select(HomeTab.settings),
                  ),
                  HomeTab.settings => SettingsView(viewModel: settings),
                },
              ),
            ),
          ),
        );
        if (bottomNavigation) return content;
        return ColoredBox(
          color: context.theme.colors.background,
          child: Row(
            children: [
              SizedBox(
                width: expandedSidebar ? 196 : 88,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border(
                      right: BorderSide(color: context.theme.colors.border),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.only(right: 1),
                    child: SafeArea(
                      child: FSidebar(
                        header: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 24,
                          ),
                          child: expandedSidebar
                              ? Text(
                                  l10n.appName,
                                  style: context.theme.typography.display.xl2
                                      .copyWith(fontSize: 22),
                                )
                              : Icon(
                                  FLucideIcons.film,
                                  semanticLabel: l10n.appName,
                                ),
                        ),
                        children: [
                          for (var index = 0; index < labels.length; index++)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  minHeight: 48,
                                ),
                                child: expandedSidebar
                                    ? FSidebarItem(
                                        icon: Icon(icons[index]),
                                        label: Text(labels[index]),
                                        selected:
                                            viewModel.selectedTab.index ==
                                            index,
                                        onPress: () => viewModel.select(
                                          HomeTab.values[index],
                                        ),
                                      )
                                    : FTooltip(
                                        tipAnchor: Alignment.centerLeft,
                                        childAnchor: Alignment.centerRight,
                                        tipBuilder: (_, _) =>
                                            Text(labels[index]),
                                        child: FButton.icon(
                                          variant: FButtonVariant.ghost,
                                          semanticsLabel: labels[index],
                                          semanticsTooltip: labels[index],
                                          selected:
                                              viewModel.selectedTab.index ==
                                              index,
                                          onPress: () => viewModel.select(
                                            HomeTab.values[index],
                                          ),
                                          child: Icon(icons[index]),
                                        ),
                                      ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(child: content),
            ],
          ),
        );
      },
    ),
  );
}
