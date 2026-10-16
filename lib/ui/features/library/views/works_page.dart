import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart' show MaterialPageRoute;

import '../../../../domain/models/local_media.dart';
import '../../../../domain/models/media_work.dart';
import '../../../../domain/models/watch_record.dart';
import '../../../../domain/models/media_organization.dart';
import '../../../../l10n/l10n.dart';
import '../view_models/library_view_model.dart';
import 'media_details_view.dart';
import 'work_assignment_page.dart';

Widget workAction(String text, VoidCallback? action, {bool selected = false}) =>
    ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: FButton(
        mainAxisSize: MainAxisSize.min,
        builder: (_, _, _, _, _, child) => Flexible(child: child!),
        selected: selected,
        variant: FButtonVariant.outline,
        onPress: action,
        child: Text(text),
      ),
    );

class WorksPage extends StatefulWidget {
  const WorksPage({
    required this.viewModel,
    this.work,
    this.choose = false,
    this.onPlayMedia,
    this.nextAfter,
    super.key,
  });
  final LibraryViewModel viewModel;
  final MediaWork? work;
  final bool choose;
  final String? nextAfter;
  final FutureOr<void> Function(BuildContext, LocalMedia)? onPlayMedia;
  @override
  State<WorksPage> createState() => _WorksPageState();
}

class _WorksPageState extends State<WorksPage> {
  late final int scope = widget.viewModel.accountRevision;
  List<MediaWork> works = [];
  List<LocalMedia> files = [];
  final Map<String, WatchRecord> watched = {};
  WatchRecord? resume;
  bool openingPlayer = false;
  final Map<String, LocalMedia> selected = {};
  bool fileMode = false,
      unresolved = false,
      loading = false,
      failed = false,
      more = false,
      confirmDetach = false;
  String query = '';
  int read = 0;
  bool get listingFiles => widget.work != null || fileMode;
  @override
  void initState() {
    super.initState();
    unawaited(load());
  }

  Future<void> load({bool next = false}) async {
    final ticket = ++read;
    setState(() {
      loading = true;
      failed = false;
    });
    try {
      final offset = next ? (listingFiles ? files.length : works.length) : 0;
      if (listingFiles) {
        final page = widget.work != null
            ? await widget.viewModel.workFiles(
                widget.work!.id,
                offset: offset,
                nextAfter: widget.nextAfter,
              )
            : await widget.viewModel.organizationFiles(
                query: query,
                offset: offset,
                unresolved: unresolved,
              );
        final pageHistory = widget.work == null
            ? <WatchRecord>[]
            : await widget.viewModel.workHistory(
                widget.work!.id,
                versionKeys: page.map((m) => m.versionKey).toList(),
              );
        final recent = widget.work == null
            ? <WatchRecord>[]
            : await widget.viewModel.workHistory(
                widget.work!.id,
                unfinished: true,
                limit: 1,
              );
        if (!mounted || ticket != read) return;
        setState(() {
          if (!next) watched.clear();
          watched.addEntries(
            pageHistory.map((r) => MapEntry(r.media.versionKey, r)),
          );
          resume = recent.firstOrNull;
          files = next ? [...files, ...page] : page;
          more = page.length == 50;
        });
      } else {
        final page = await widget.viewModel.works(query: query, offset: offset);
        if (!mounted || ticket != read) return;
        setState(() {
          works = next ? [...works, ...page] : page;
          more = page.length == 50;
        });
      }
    } catch (_) {
      if (mounted && ticket == read) setState(() => failed = true);
    } finally {
      if (mounted && ticket == read) setState(() => loading = false);
    }
  }

  Future<void> play(LocalMedia media) async {
    if (openingPlayer ||
        widget.onPlayMedia == null ||
        scope != widget.viewModel.accountRevision ||
        !widget.viewModel.ready) {
      return;
    }
    setState(() => openingPlayer = true);
    try {
      await widget.onPlayMedia!(context, media);
      if (mounted) await load();
    } catch (_) {
      if (mounted) setState(() => failed = true);
    } finally {
      if (mounted) setState(() => openingPlayer = false);
    }
  }

  Future<void> nextEpisode(LocalMedia media) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => WorksPage(
          viewModel: widget.viewModel,
          work: widget.work,
          nextAfter: media.versionKey,
          onPlayMedia: widget.onPlayMedia,
        ),
      ),
    );
    if (mounted) await load();
  }

  Future<void> assign() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => WorkAssignmentPage(
          viewModel: widget.viewModel,
          files: selected.values.toList(),
          initialWork: widget.work,
          scope: scope,
        ),
      ),
    );
    if (!mounted || changed != true) return;
    setState(() {
      selected.clear();
      confirmDetach = false;
    });
    await load();
  }

  Future<void> detach() async {
    if (!confirmDetach) {
      setState(() => confirmDetach = true);
      return;
    }
    setState(() => loading = true);
    try {
      await widget.viewModel.unassignWork(scope, selected.keys.toList());
      if (!mounted) return;
      setState(() {
        selected.clear();
        confirmDetach = false;
      });
      await load();
    } catch (_) {
      if (mounted) {
        setState(() {
          failed = true;
          loading = false;
        });
      }
    }
  }

  void resetSearch() {
    ++read;
    selected.clear();
    files = [];
    works = [];
    confirmDetach = false;
    unawaited(load());
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.viewModel,
    builder: (context, _) {
      final l = context.l10n;
      return FScaffold(
        header: FHeader.nested(
          title: Text(
            scope == widget.viewModel.accountRevision && widget.viewModel.ready
                ? widget.work?.title ?? l.worksTitle
                : l.worksTitle,
          ),
          prefixes: [
            SizedBox(
              width: 48,
              height: 48,
              child: FHeaderAction.back(
                onPress: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
        child:
            scope != widget.viewModel.accountRevision || !widget.viewModel.ready
            ? Center(child: Text(l.libraryDetailsUnavailable))
            : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1080),
                  child: ListView(
                    key: const PageStorageKey('work-list'),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    children: [
                      if (widget.work == null) ...[
                        FTextField(
                          label: Text(l.librarySearch),
                          control: FTextFieldControl.managed(
                            onChange: (v) {
                              query = v.text;
                              resetSearch();
                            },
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (!widget.choose)
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              workAction(
                                l.worksTitle,
                                loading
                                    ? null
                                    : () {
                                        setState(() => fileMode = false);
                                        resetSearch();
                                      },
                                selected: !fileMode,
                              ),
                              workAction(
                                l.worksOrganizeFiles,
                                loading
                                    ? null
                                    : () {
                                        setState(() => fileMode = true);
                                        resetSearch();
                                      },
                                selected: fileMode,
                              ),
                              if (fileMode)
                                workAction(
                                  l.mediaUnresolved,
                                  loading
                                      ? null
                                      : () {
                                          setState(
                                            () => unresolved = !unresolved,
                                          );
                                          resetSearch();
                                        },
                                  selected: unresolved,
                                ),
                            ],
                          ),
                      ] else
                        Text(
                          '${widget.work!.kind == MediaKind.series ? l.mediaSeries : l.mediaMovie} · ${widget.work!.year ?? l.worksUnknownYear}',
                        ),
                      const SizedBox(height: 16),
                      if (widget.work != null &&
                          resume != null &&
                          widget.nextAfter == null) ...[
                        Text(resume!.media.fileName),
                        workAction(
                          l.continueWatching,
                          loading || openingPlayer || widget.onPlayMedia == null
                              ? null
                              : () => play(resume!.media),
                        ),
                      ],
                      if (widget.nextAfter != null)
                        Text(l.worksChooseNextVersion),
                      if (listingFiles) ...[
                        if (widget.nextAfter == null)
                          Text(l.worksSelectionNotice),
                        if (selected.isNotEmpty) ...[
                          Text(l.worksSelected(selected.length)),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              workAction(
                                l.worksAssign,
                                loading ? null : assign,
                              ),
                              workAction(
                                confirmDetach
                                    ? l.worksConfirmDetach
                                    : l.worksDetach,
                                loading ? null : detach,
                              ),
                              workAction(
                                l.cancelAction,
                                loading
                                    ? null
                                    : () => setState(() {
                                        selected.clear();
                                        confirmDetach = false;
                                      }),
                              ),
                            ],
                          ),
                          if (confirmDetach) Text(l.worksDetachNotice),
                        ],
                        for (var i = 0; i < files.length; i++) ...[
                          if (widget.work?.kind == MediaKind.series &&
                              (i == 0 ||
                                  files[i].organization.season !=
                                      files[i - 1].organization.season ||
                                  files[i].organization.episode !=
                                      files[i - 1].organization.episode))
                            Padding(
                              padding: const EdgeInsets.only(
                                top: 20,
                                bottom: 8,
                              ),
                              child: Text(
                                l.worksEpisode(
                                  files[i].organization.season ?? 0,
                                  files[i].organization.episode ?? 0,
                                ),
                                style: context.theme.typography.body.lg,
                              ),
                            ),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(files[i].fileName),
                                if (widget.work != null)
                                  Text(
                                    watched[files[i].versionKey]?.completed ==
                                            true
                                        ? l.historyCompleted
                                        : watched[files[i].versionKey] == null
                                        ? l.worksUnwatched
                                        : l.worksWatchedPosition(
                                            watched[files[i].versionKey]!
                                                .position
                                                .inMinutes,
                                          ),
                                  ),
                                Text(
                                  '${widget.viewModel.sourceTitle(files[i].sourceId)} · ${mediaSize(files[i].sizeBytes)}',
                                ),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    if (widget.work != null) ...[
                                      workAction(
                                        l.libraryPlay,
                                        loading ||
                                                openingPlayer ||
                                                widget.onPlayMedia == null
                                            ? null
                                            : () => play(files[i]),
                                      ),
                                      if (widget.work!.kind ==
                                              MediaKind.series &&
                                          files[i].organization.season !=
                                              null &&
                                          files[i].organization.episode != null)
                                        workAction(
                                          l.worksNextEpisode,
                                          loading || openingPlayer
                                              ? null
                                              : () => nextEpisode(files[i]),
                                        ),
                                    ],
                                    if (widget.nextAfter == null)
                                      workAction(
                                        selected.containsKey(
                                              files[i].versionKey,
                                            )
                                            ? l.worksDeselect
                                            : l.worksSelect,
                                        loading ||
                                                (!selected.containsKey(
                                                      files[i].versionKey,
                                                    ) &&
                                                    selected.length >= 100)
                                            ? null
                                            : () => setState(() {
                                                if (selected.remove(
                                                      files[i].versionKey,
                                                    ) ==
                                                    null) {
                                                  selected[files[i]
                                                          .versionKey] =
                                                      files[i];
                                                }
                                                confirmDetach = false;
                                              }),
                                        selected: selected.containsKey(
                                          files[i].versionKey,
                                        ),
                                      ),
                                    workAction(
                                      l.libraryFileDetails,
                                      loading
                                          ? null
                                          : () async {
                                              await Navigator.of(
                                                context,
                                              ).push<void>(
                                                MaterialPageRoute(
                                                  builder: (context) => ListenableBuilder(
                                                    listenable:
                                                        widget.viewModel,
                                                    builder: (context, _) => FScaffold(
                                                      header: FHeader.nested(
                                                        title: Text(
                                                          l.libraryFileDetails,
                                                        ),
                                                        prefixes: [
                                                          SizedBox(
                                                            width: 48,
                                                            height: 48,
                                                            child: FHeaderAction.back(
                                                              onPress: () =>
                                                                  Navigator.of(
                                                                    context,
                                                                  ).pop(),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      child:
                                                          scope !=
                                                                  widget
                                                                      .viewModel
                                                                      .accountRevision ||
                                                              !widget
                                                                  .viewModel
                                                                  .ready
                                                          ? Text(
                                                              l.libraryDetailsUnavailable,
                                                            )
                                                          : MediaDetails(
                                                              viewModel: widget
                                                                  .viewModel,
                                                              media: files[i],
                                                              onPlayMedia: widget
                                                                  .onPlayMedia,
                                                            ),
                                                    ),
                                                  ),
                                                ),
                                              );
                                              if (mounted) {
                                                selected.clear();
                                                await load();
                                              }
                                            },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ] else
                        for (final work in works)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: workAction(
                              '${work.title} · ${work.year ?? l.worksUnknownYear}\n${l.worksFileCount(work.fileCount)}',
                              loading
                                  ? null
                                  : () async {
                                      if (widget.choose) {
                                        Navigator.of(context).pop(work);
                                        return;
                                      }
                                      await Navigator.of(context).push<void>(
                                        MaterialPageRoute(
                                          builder: (_) => WorksPage(
                                            viewModel: widget.viewModel,
                                            work: work,
                                            onPlayMedia: widget.onPlayMedia,
                                          ),
                                        ),
                                      );
                                      if (mounted) await load();
                                    },
                            ),
                          ),
                      if (!loading &&
                          !failed &&
                          (listingFiles ? files.isEmpty : works.isEmpty))
                        Text(
                          widget.nextAfter == null
                              ? l.worksEmpty
                              : l.worksNoNextEpisode,
                        ),
                      if (failed) ...[
                        Semantics(
                          liveRegion: true,
                          child: Text(l.libraryStorageError),
                        ),
                        workAction(
                          l.libraryRetry,
                          loading ? null : () => load(),
                        ),
                      ],
                      if (loading)
                        Semantics(
                          liveRegion: true,
                          child: Text(l.libraryLoading),
                        ),
                      if (more && !loading)
                        workAction(l.worksLoadMore, () => load(next: true)),
                    ],
                  ),
                ),
              ),
      );
    },
  );
}
