import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import '../../../../l10n/l10n.dart';
import '../../history/views/history_view.dart';
import '../../library/views/library_view.dart';
import '../../settings/views/settings_view.dart';
import '../view_models/home_view_model.dart';

class HomeView extends StatelessWidget {
  const HomeView({required this.viewModel, super.key});

  final HomeViewModel viewModel;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: viewModel,
    builder: (context, _) {
      final l10n = context.l10n;
      return FScaffold(
        header: FHeader(
          title: Text(switch (viewModel.selectedTab) {
            HomeTab.library => l10n.appName,
            HomeTab.history => l10n.historyTitle,
            HomeTab.settings => l10n.settingsTitle,
          }),
        ),
        footer: FBottomNavigationBar(
          index: viewModel.selectedTab.index,
          safeAreaBottom: true,
          onChange: (index) => viewModel.select(HomeTab.values[index]),
          children: [
            FBottomNavigationBarItem(
              icon: const Icon(FLucideIcons.film),
              label: Text(l10n.libraryTab),
            ),
            FBottomNavigationBarItem(
              icon: const Icon(FLucideIcons.history),
              label: Text(l10n.historyTab),
            ),
            FBottomNavigationBarItem(
              icon: const Icon(FLucideIcons.settings),
              label: Text(l10n.settingsTitle),
            ),
          ],
        ),
        child: switch (viewModel.selectedTab) {
          HomeTab.library => LibraryView(
            onOpenSettings: () => viewModel.select(HomeTab.settings),
          ),
          HomeTab.history => HistoryView(
            onOpenLibrary: () => viewModel.select(HomeTab.library),
          ),
          HomeTab.settings => const SettingsView(),
        },
      );
    },
  );
}
