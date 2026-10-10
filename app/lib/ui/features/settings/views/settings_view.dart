import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import '../../../../l10n/l10n.dart';

class SettingsView extends StatelessWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        FTileGroup(
          label: Text(context.l10n.connectionSection),
          description: Text(context.l10n.connectionUnavailable),
          children: [
            FTile(
              prefix: const Icon(FLucideIcons.send),
              title: Text(context.l10n.telegram),
              details: Text(context.l10n.notConnected),
            ),
            FTile(
              prefix: const Icon(FLucideIcons.cloud),
              title: Text(context.l10n.relayService),
              details: Text(context.l10n.notConfigured),
            ),
          ],
        ),
      ],
    ),
  );
}
