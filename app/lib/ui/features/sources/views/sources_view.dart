import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import '../../../../l10n/l10n.dart';
import '../../../core/app_empty_state.dart';

class SourcesView extends StatelessWidget {
  const SourcesView({required this.onOpenSettings, super.key});

  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) => AppEmptyState(
    icon: FLucideIcons.folderOpen,
    title: context.l10n.sourcesEmptyTitle,
    description: context.l10n.sourcesEmptyDescription,
    action: context.l10n.connectionDetails,
    onPress: onOpenSettings,
  );
}
