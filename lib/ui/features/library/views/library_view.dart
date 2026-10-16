import '../../../../domain/models/media_organization.dart';
import '../../history/views/watch_record_tile.dart';

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:material_ui/material_ui.dart' show MaterialPageRoute;
import 'package:forui/forui.dart';

import '../../../../l10n/l10n.dart';
import '../../../../domain/models/telegram_account.dart';
import '../../../../domain/models/local_media.dart';
import '../../../core/app_empty_state.dart';
import '../view_models/library_view_model.dart';
import 'media_details_view.dart';
import 'works_page.dart';

class LibraryView extends StatelessWidget {
  const LibraryView({
    required this.onOpenSources,
    this.onOpenPlayer,
    this.viewModel,
    this.onPlayMedia,
    super.key,
  });
  final VoidCallback onOpenSources;
  final VoidCallback? onOpenPlayer;
  final FutureOr<void> Function(BuildContext, LocalMedia)? onPlayMedia;
  final LibraryViewModel? viewModel;

  Widget _empty(BuildContext context) => AppEmptyState(
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

  @override
  Widget build(BuildContext context) {
    final vm = viewModel;
    if (vm == null) return _empty(context);
    return ListenableBuilder(
      listenable: vm,
      builder: (context, _) {
        if (!vm.ready ||
            (!vm.loading &&
                vm.failure == null &&
                vm.imports.isEmpty &&
                vm.media.isEmpty)) {
          return _empty(context);
        }
        return LayoutBuilder(
          builder: (context, constraints) {
            final wide =
                constraints.maxWidth >= 860 &&
                MediaQuery.textScalerOf(context).scale(16) / 16 < 1.6;
            final l10n = context.l10n;
            final importCount = vm.showImports ? vm.imports.length : 0;
            final list = ListView.builder(
              key: const PageStorageKey('library-files'),
              padding: const EdgeInsets.only(top: 20, bottom: 24),
              itemCount: vm.media.length + importCount + 2,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FTextField(
                        key: ValueKey('library-query-${vm.queryRevision}'),
                        label: Text(l10n.librarySearch),
                        control: FTextFieldControl.managed(
                          initial: TextEditingValue(text: vm.query),
                          onChange: (value) => vm.search(value.text),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          workAction(
                            l10n.worksTitle,
                            () => Navigator.of(context).push<void>(
                              MaterialPageRoute(
                                builder: (_) => WorksPage(
                                  viewModel: vm,
                                  onPlayMedia: onPlayMedia,
                                ),
                              ),
                            ),
                          ),
                          ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 48),
                            child: FButton(
                              mainAxisSize: MainAxisSize.min,
                              variant: FButtonVariant.outline,
                              onPress: vm.toggleImports,
                              child: Text(l10n.libraryImportSources),
                            ),
                          ),
                          ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 48),
                            child: FButton(
                              mainAxisSize: MainAxisSize.min,
                              variant: FButtonVariant.ghost,
                              onPress: onOpenSources,
                              child: Text(l10n.libraryManageSources),
                            ),
                          ),
                          if (onOpenPlayer != null)
                            FButton(
                              variant: FButtonVariant.ghost,
                              onPress: onOpenPlayer,
                              child: Text(l10n.openSelectedVideo),
                            ),
                        ],
                      ),

                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final option in <MediaKind?>[
                            null,
                            ...MediaKind.values,
                          ])
                            ConstrainedBox(
                              constraints: const BoxConstraints(minHeight: 48),
                              child: FButton(
                                mainAxisSize: MainAxisSize.min,
                                variant: vm.kind == option
                                    ? FButtonVariant.primary
                                    : FButtonVariant.outline,
                                onPress: () => vm.filter(option),
                                child: Text(switch (option) {
                                  null => l10n.mediaAll,
                                  MediaKind.movie => l10n.mediaMovie,
                                  MediaKind.series => l10n.mediaSeries,
                                  MediaKind.unresolved => l10n.mediaUnresolved,
                                }),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (vm.query.isEmpty &&
                          vm.kind == null &&
                          vm.continuing.isNotEmpty) ...[
                        Text(
                          l10n.continueWatching,
                          style: context.theme.typography.body.lg.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        for (final record in vm.continuing)
                          WatchRecordTile(
                            record: record,
                            onPlayMedia: onPlayMedia,
                          ),
                        const SizedBox(height: 24),
                      ],
                      if (vm.failure != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Semantics(
                            liveRegion: true,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  vm.failure == TelegramFailure.storage
                                      ? l10n.libraryStorageError
                                      : vm.failure ==
                                            TelegramFailure.serviceLimited
                                      ? l10n.telegramServiceLimited
                                      : l10n.libraryImportError,
                                ),
                                const SizedBox(height: 8),
                                ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    minHeight: 48,
                                  ),
                                  child: FButton(
                                    variant: FButtonVariant.outline,
                                    onPress: () => unawaited(vm.refresh()),
                                    child: Text(l10n.libraryRetry),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      if (vm.showImports && vm.imports.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Text(
                            l10n.libraryImportNotice,
                            style: context.theme.typography.body.sm.copyWith(
                              color: context.theme.colors.mutedForeground,
                            ),
                          ),
                        ),
                    ],
                  );
                }
                if (index <= importCount) {
                  return _Imports(viewModel: vm, source: vm.imports[index - 1]);
                }
                if (index == vm.media.length + importCount + 1) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (vm.media.isEmpty && !vm.loading) ...[
                        Text(
                          vm.query.isEmpty
                              ? l10n.libraryNoMedia
                              : l10n.libraryNoResults,
                          style: context.theme.typography.body.lg,
                        ),
                        const SizedBox(height: 12),
                        if (vm.query.isEmpty) Text(l10n.libraryNoMediaBody),
                        if (vm.query.isNotEmpty)
                          FButton(
                            variant: FButtonVariant.outline,
                            onPress: vm.clearSearch,
                            child: Text(l10n.libraryClearSearch),
                          ),
                      ],
                      if (vm.loading) _Loading(),
                      if (vm.hasMore && !vm.loading)
                        ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 48),
                          child: FButton(
                            variant: FButtonVariant.outline,
                            onPress: () => unawaited(vm.refresh(more: true)),
                            child: Text(l10n.libraryLoadMore),
                          ),
                        ),
                    ],
                  );
                }
                final item = vm.media[index - importCount - 1];
                final title = item.organization.title.isNotEmpty
                    ? item.organization.title
                    : item.fileName.isEmpty
                    ? l10n.libraryUnknownFile
                    : item.fileName;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 88),
                    child: FButton(
                      key: ValueKey('media-${item.versionKey}'),
                      variant: FButtonVariant.ghost,
                      selected: vm.selected?.versionKey == item.versionKey,
                      builder: (_, _, _, _, _, child) =>
                          Expanded(child: child!),
                      onPress: () {
                        vm.select(item);
                        if (!wide) {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => MediaDetailsPage(
                                viewModel: vm,
                                onPlayMedia: onPlayMedia,
                              ),
                            ),
                          );
                        }
                      },
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: context.theme.typography.body.md
                                      .copyWith(fontWeight: FontWeight.w600),
                                ),
                                if (item.organization.title.isNotEmpty)
                                  Text(
                                    item.fileName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                const SizedBox(height: 8),
                                Text(
                                  vm.sourceTitle(item.sourceId),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Wrap(
                                  spacing: 12,
                                  runSpacing: 4,
                                  children: [
                                    Text(mediaSize(item.sizeBytes)),
                                    Text(
                                      mediaDuration(
                                        context,
                                        item.durationSeconds,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Icon(FLucideIcons.chevronRight, size: 18),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
            return wide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(flex: 6, child: list),
                      const SizedBox(width: 24),
                      Expanded(
                        flex: 5,
                        child: vm.selected != null
                            ? MediaDetails(
                                onPlayMedia: onPlayMedia,
                                viewModel: vm,
                                media: vm.selected!,
                                key: ValueKey(vm.selected!.versionKey),
                              )
                            : Center(
                                child: Text(
                                  l10n.librarySelectFile,
                                  textAlign: TextAlign.center,
                                  style: context.theme.typography.body.md,
                                ),
                              ),
                      ),
                    ],
                  )
                : list;
          },
        );
      },
    );
  }
}

class _Imports extends StatelessWidget {
  const _Imports({required this.viewModel, required this.source});
  final LibraryViewModel viewModel;
  final SourceImport source;
  @override
  Widget build(BuildContext context) {
    final vm = viewModel;
    final row = source;
    final l10n = context.l10n;
    final current = vm.runningSource == row.sourceId;
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            row.title.isEmpty ? l10n.libraryUnknownSource : row.title,
            style: context.theme.typography.body.md.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(l10n.libraryImportCount(row.imported)),
          const SizedBox(height: 4),
          Semantics(
            liveRegion: true,
            child: Text(
              current
                  ? (vm.updating
                        ? l10n.libraryCheckingUpdates
                        : l10n.libraryImportRunning)
                  : row.checkpoint.complete
                  ? l10n.libraryImportComplete
                  : row.checkpoint.paused
                  ? l10n.libraryImportPaused
                  : l10n.libraryImportIdle,
              style: context.theme.typography.body.sm.copyWith(
                color: context.theme.colors.mutedForeground,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(l10n.libraryUpdateNotice),
          if (row.update.checkedAt != null) Text(l10n.libraryUpdatesChecked),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: FButton(
                variant: FButtonVariant.outline,
                onPress: vm.pausing || vm.runningSource != null
                    ? null
                    : () => unawaited(vm.start(row.sourceId, updates: true)),
                child: Text(
                  row.update.pending
                      ? l10n.libraryResumeUpdates
                      : l10n.libraryCheckUpdates,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (!row.checkpoint.complete || current)
            Align(
              alignment: Alignment.centerLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: FButton(
                  key: ValueKey('import-${row.sourceId}'),
                  variant: current
                      ? FButtonVariant.outline
                      : FButtonVariant.primary,
                  onPress: vm.pausing || (vm.runningSource != null && !current)
                      ? null
                      : () => unawaited(
                          current ? vm.pause() : vm.start(row.sourceId),
                        ),
                  child: Text(
                    current
                        ? l10n.libraryImportPause
                        : row.checkpoint.revision == 0
                        ? l10n.libraryImportStart
                        : l10n.libraryImportContinue,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(liveRegion: true, child: Text(context.l10n.libraryLoading)),
        const SizedBox(height: 16),
        ExcludeSemantics(
          child: Column(
            children: [
              for (var index = 0; index < 3; index++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: SizedBox(
                    height: 16,
                    width: double.infinity,
                    child: ColoredBox(color: context.theme.colors.muted),
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}
