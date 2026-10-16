import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import '../../../../domain/models/local_media.dart';
import '../../../../domain/models/watch_record.dart';
import '../../../../l10n/l10n.dart';
import '../../library/views/media_details_view.dart';

class WatchRecordTile extends StatelessWidget {
  const WatchRecordTile({
    required this.record,
    this.onPlayMedia,
    this.onRemove,
    super.key,
  });
  final WatchRecord record;
  final FutureOr<void> Function(BuildContext, LocalMedia)? onPlayMedia;
  final VoidCallback? onRemove;
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final date = record.watchedAt?.toLocal();
    final time = date == null
        ? l10n.historyUnknownDate
        : '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            record.media.fileName.isEmpty
                ? l10n.libraryUnknownFile
                : record.media.fileName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: context.theme.typography.body.md.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            record.sourceTitle.isEmpty
                ? l10n.libraryUnknownSource
                : record.sourceTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(time, style: context.theme.typography.body.sm),
          const SizedBox(height: 6),
          Text(
            record.completed
                ? l10n.historyCompleted
                : l10n.historyProgress(
                    record.position == Duration.zero
                        ? '0:00:00'
                        : mediaDuration(context, record.position.inSeconds),
                    mediaDuration(context, record.duration.inSeconds),
                  ),
          ),
          if (!record.available) Text(l10n.historyUnavailable),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (onPlayMedia != null)
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: FButton(
                    mainAxisSize: MainAxisSize.min,
                    variant: FButtonVariant.outline,
                    onPress: record.available
                        ? () => onPlayMedia!(context, record.media)
                        : null,
                    child: Text(
                      record.completed
                          ? l10n.historyReplay
                          : l10n.historyContinue,
                    ),
                  ),
                ),
              if (onRemove != null)
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: FButton(
                    mainAxisSize: MainAxisSize.min,
                    variant: FButtonVariant.ghost,
                    onPress: onRemove,
                    child: Text(l10n.historyRemove),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
