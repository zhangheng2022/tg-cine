import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import '../../../../domain/models/local_media.dart';
import '../../../../l10n/l10n.dart';
import '../../../core/app_empty_state.dart';
import '../../library/view_models/library_view_model.dart';
import 'watch_record_tile.dart';

class HistoryView extends StatefulWidget {
  const HistoryView({
    required this.onOpenLibrary,
    this.viewModel,
    this.onPlayMedia,
    super.key,
  });
  final VoidCallback onOpenLibrary;
  final LibraryViewModel? viewModel;
  final FutureOr<void> Function(BuildContext, LocalMedia)? onPlayMedia;
  @override
  State<HistoryView> createState() => _HistoryViewState();
}

class _HistoryViewState extends State<HistoryView> {
  int? _confirmationScope;
  @override
  Widget build(BuildContext context) {
    final vm = widget.viewModel;
    Widget empty() => AppEmptyState(
      icon: FLucideIcons.history,
      title: context.l10n.historyEmptyTitle,
      description: context.l10n.historyEmptyDescription,
      action: context.l10n.openLibrary,
      onPress: widget.onOpenLibrary,
    );
    if (vm == null) return empty();
    return ListenableBuilder(
      listenable: vm,
      builder: (context, _) {
        final l10n = context.l10n;
        final confirm = _confirmationScope == vm.accountRevision;
        if (!vm.ready ||
            (vm.history.isEmpty &&
                !vm.historyLoading &&
                vm.historyFailure == null)) {
          return empty();
        }
        return ListView(
          key: const PageStorageKey('watch-history'),
          padding: const EdgeInsets.symmetric(vertical: 16),
          children: [
            Text(l10n.historyLocalNotice),
            const SizedBox(height: 12),
            if (vm.history.isNotEmpty) ...[
              if (confirm) Text(l10n.historyClearNotice),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 48),
                    child: FButton(
                      mainAxisSize: MainAxisSize.min,
                      variant: FButtonVariant.outline,
                      onPress: vm.historyBusy
                          ? null
                          : () async {
                              if (!confirm) {
                                setState(
                                  () => _confirmationScope = vm.accountRevision,
                                );
                                return;
                              }
                              await vm.removeHistory();
                              if (mounted) {
                                setState(() => _confirmationScope = null);
                              }
                            },
                      child: Text(
                        confirm ? l10n.historyConfirmClear : l10n.historyClear,
                      ),
                    ),
                  ),
                  if (confirm)
                    ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 48),
                      child: FButton(
                        mainAxisSize: MainAxisSize.min,
                        variant: FButtonVariant.ghost,
                        onPress: vm.historyBusy
                            ? null
                            : () => setState(() => _confirmationScope = null),
                        child: Text(l10n.cancelAction),
                      ),
                    ),
                ],
              ),
            ],
            if (vm.historyFailure != null) ...[
              Semantics(liveRegion: true, child: Text(l10n.historyError)),
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: FButton(
                  onPress: () => unawaited(vm.refreshHistory()),
                  child: Text(l10n.libraryRetry),
                ),
              ),
            ],
            for (final record in vm.history)
              WatchRecordTile(
                record: record,
                onPlayMedia: widget.onPlayMedia,
                onRemove: vm.historyBusy
                    ? null
                    : () => unawaited(
                        vm.removeHistory(versionKey: record.media.versionKey),
                      ),
              ),
            if (vm.historyLoading)
              Semantics(liveRegion: true, child: Text(l10n.libraryLoading)),
            if (vm.historyHasMore && !vm.historyLoading)
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: FButton(
                  onPress: () => unawaited(vm.refreshHistory(more: true)),
                  child: Text(l10n.libraryLoadMore),
                ),
              ),
          ],
        );
      },
    );
  }
}
