import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart' show MaterialPageRoute;

import '../../../../domain/models/app_settings.dart';
import '../../../../l10n/l10n.dart';
import '../../privacy/views/local_data_view.dart';
import '../view_models/settings_view_model.dart';

class SettingsView extends StatelessWidget {
  const SettingsView({required this.viewModel, super.key});

  final SettingsViewModel viewModel;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: viewModel,
    builder: (context, _) {
      final l10n = context.l10n;
      return SingleChildScrollView(
        child: Align(
          alignment: Alignment.topLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FTileGroup(
                    label: Text(l10n.connectionSection),
                    description: Text(l10n.connectionUnavailable),
                    children: [
                      FTile(
                        prefix: const Icon(FLucideIcons.send),
                        title: Text(l10n.telegram),
                        details: Text(l10n.notConnected),
                      ),
                      FTile(
                        prefix: const Icon(FLucideIcons.cloud),
                        title: Text(l10n.defaultService),
                        details: Text(l10n.serviceUnavailable),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  Text(
                    l10n.appearanceTitle,
                    style: context.theme.typography.body.lg.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.localSettingDescription,
                    style: context.theme.typography.body.sm.copyWith(
                      color: context.theme.colors.mutedForeground,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (viewModel.loading)
                    Text(l10n.loadingSettings)
                  else if (viewModel.loadFailed) ...[
                    Text(l10n.loadSettingsError),
                    const SizedBox(height: 12),
                    ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 48),
                      child: FButton(
                        onPress: () => unawaited(viewModel.load()),
                        child: Text(l10n.retry),
                      ),
                    ),
                  ] else ...[
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final appearance in AppAppearance.values)
                          ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 48),
                            child: FButton(
                              variant: viewModel.appearance == appearance
                                  ? FButtonVariant.primary
                                  : FButtonVariant.outline,
                              selected: viewModel.appearance == appearance,
                              mainAxisSize: MainAxisSize.min,
                              onPress: viewModel.saving
                                  ? null
                                  : () => unawaited(
                                      viewModel.setAppearance(appearance),
                                    ),
                              child: Text(switch (appearance) {
                                AppAppearance.system => l10n.themeSystem,
                                AppAppearance.light => l10n.themeLight,
                                AppAppearance.dark => l10n.themeDark,
                              }),
                            ),
                          ),
                      ],
                    ),
                    if (viewModel.saving) ...[
                      const SizedBox(height: 12),
                      Text(l10n.savingSettings),
                    ],
                    if (viewModel.saveFailed) ...[
                      const SizedBox(height: 12),
                      Text(l10n.saveSettingsError),
                    ],
                  ],
                  const SizedBox(height: 32),
                  FTileGroup(
                    label: Text(l10n.aboutSection),
                    children: [
                      FTile(
                        prefix: const Icon(FLucideIcons.shield),
                        title: Text(l10n.localDataTitle),
                        suffix: const Icon(FLucideIcons.chevronRight),
                        onPress: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const LocalDataView(),
                          ),
                        ),
                      ),
                      FTile(
                        prefix: const Icon(FLucideIcons.info),
                        title: Text(l10n.appName),
                        subtitle: Text(l10n.unofficialNotice),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}
