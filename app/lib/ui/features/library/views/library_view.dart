import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import '../../../../l10n/l10n.dart';
import '../../../core/app_empty_state.dart';

class LibraryView extends StatelessWidget {
  const LibraryView({required this.onOpenSettings, super.key});

  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) => AppEmptyState(
    icon: FLucideIcons.film,
    title: context.l10n.libraryEmptyTitle,
    description: context.l10n.libraryEmptyDescription,
    action: context.l10n.openSettings,
    onPress: onOpenSettings,
  );
}
