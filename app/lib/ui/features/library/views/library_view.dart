import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import '../../../../l10n/l10n.dart';
import '../../../core/app_empty_state.dart';

class LibraryView extends StatelessWidget {
  const LibraryView({
    required this.onOpenSources,
    this.onOpenPlayer,
    super.key,
  });

  final VoidCallback onOpenSources;
  final VoidCallback? onOpenPlayer;

  @override
  Widget build(BuildContext context) => AppEmptyState(
    icon: FLucideIcons.film,
    title: onOpenPlayer == null
        ? context.l10n.libraryEmptyTitle
        : context.l10n.selectedVideo,
    description: onOpenPlayer == null
        ? context.l10n.libraryEmptyDescription
        : context.l10n.developmentSelectedNotice,
    action: onOpenPlayer == null
        ? context.l10n.openSources
        : context.l10n.openSelectedVideo,
    onPress: onOpenPlayer ?? onOpenSources,
  );
}
