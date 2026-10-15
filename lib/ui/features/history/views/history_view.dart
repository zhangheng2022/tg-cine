import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import '../../../../l10n/l10n.dart';
import '../../../core/app_empty_state.dart';

class HistoryView extends StatelessWidget {
  const HistoryView({required this.onOpenLibrary, super.key});

  final VoidCallback onOpenLibrary;

  @override
  Widget build(BuildContext context) => AppEmptyState(
    icon: FLucideIcons.history,
    title: context.l10n.historyEmptyTitle,
    description: context.l10n.historyEmptyDescription,
    action: context.l10n.openLibrary,
    onPress: onOpenLibrary,
  );
}
