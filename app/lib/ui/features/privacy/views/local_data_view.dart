import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import '../../../../l10n/l10n.dart';

class LocalDataView extends StatelessWidget {
  const LocalDataView({super.key});

  @override
  Widget build(BuildContext context) => FScaffold(
    header: FHeader.nested(
      title: Text(context.l10n.localDataTitle),
      prefixes: [
        SizedBox(
          width: 48,
          height: 48,
          child: FButton.icon(
            variant: FButtonVariant.ghost,
            semanticsLabel: context.l10n.back,
            onPress: () => Navigator.of(context).pop(),
            child: const Icon(FLucideIcons.arrowLeft),
          ),
        ),
      ],
    ),
    child: SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.localDataHeading,
                  style: context.theme.typography.display.xl2,
                ),
                const SizedBox(height: 16),
                Text(
                  context.l10n.localDataBody,
                  style: context.theme.typography.body.md,
                ),
                const SizedBox(height: 32),
                Text(
                  context.l10n.mediaRightsHeading,
                  style: context.theme.typography.body.lg.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  context.l10n.mediaRightsBody,
                  style: context.theme.typography.body.md,
                ),
                const SizedBox(height: 32),
                Text(
                  context.l10n.unofficialNotice,
                  style: context.theme.typography.body.sm.copyWith(
                    color: context.theme.colors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
