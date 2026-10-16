import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart' show MaterialPageRoute;

import '../../../../domain/models/local_media.dart';
import '../../../../domain/models/media_work.dart';
import '../../../../domain/models/media_organization.dart';
import '../../../../l10n/l10n.dart';
import '../view_models/library_view_model.dart';
import 'works_page.dart';

class WorkAssignmentPage extends StatefulWidget {
  const WorkAssignmentPage({
    required this.viewModel,
    required this.files,
    required this.scope,
    this.initialWork,
    super.key,
  });
  final LibraryViewModel viewModel;
  final List<LocalMedia> files;
  final int scope;
  final MediaWork? initialWork;
  @override
  State<WorkAssignmentPage> createState() => _WorkAssignmentPageState();
}

class _WorkAssignmentPageState extends State<WorkAssignmentPage> {
  MediaWork? target;
  String title = '', year = '';
  MediaKind kind = MediaKind.movie;
  final Map<String, String> seasons = {}, episodes = {};
  bool preview = false, busy = false, invalid = false, failed = false;
  @override
  void initState() {
    super.initState();
    target = widget.initialWork;
    title = target?.title ?? '';
    year = target?.year?.toString() ?? '';
    kind = target?.kind ?? MediaKind.movie;
    for (final f in widget.files) {
      seasons[f.versionKey] = f.organization.season?.toString() ?? '';
      episodes[f.versionKey] = f.organization.episode?.toString() ?? '';
    }
  }

  int? number(String v) =>
      v.trim().isEmpty ? null : int.tryParse(v.trim()) ?? -1;
  MediaWork get work =>
      target ?? MediaWork(title: title.trim(), kind: kind, year: number(year));
  List<WorkFileEdit> get edits => [
    for (final f in widget.files)
      WorkFileEdit(
        f.versionKey,
        season: work.kind == MediaKind.series
            ? number(seasons[f.versionKey]!)
            : null,
        episode: work.kind == MediaKind.series
            ? number(episodes[f.versionKey]!)
            : null,
      ),
  ];
  void prepare() {
    final w = work;
    final valid =
        w.valid &&
        edits.every(
          (f) => MediaOrganization(
            title: w.title,
            kind: w.kind,
            year: w.year,
            season: f.season,
            episode: f.episode,
          ).valid,
        );
    setState(() {
      invalid = !valid;
      preview = valid;
      failed = false;
    });
  }

  Future<void> save() async {
    if (!preview || busy) return;
    setState(() => busy = true);
    try {
      await widget.viewModel.assignWork(widget.scope, work, edits);
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) setState(() => failed = true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> choose() async {
    final result = await Navigator.of(context).push<MediaWork>(
      MaterialPageRoute(
        builder: (_) => WorksPage(viewModel: widget.viewModel, choose: true),
      ),
    );
    if (mounted && result != null) setState(() => target = result);
  }

  Widget field(
    String key,
    String label,
    String value,
    ValueChanged<String> change, {
    bool numeric = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: FTextField(
      key: ValueKey(key),
      enabled: !busy,
      label: Text(label),
      keyboardType: numeric ? TextInputType.number : TextInputType.text,
      control: FTextFieldControl.managed(
        initial: TextEditingValue(text: value),
        onChange: (v) => change(v.text),
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.viewModel,
    builder: (context, _) {
      final l = context.l10n;
      return FScaffold(
        header: FHeader.nested(
          title: Text(l.worksAssign),
          prefixes: [
            SizedBox(
              width: 48,
              height: 48,
              child: FHeaderAction.back(
                onPress: busy ? null : () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
        child:
            widget.scope != widget.viewModel.accountRevision ||
                !widget.viewModel.ready
            ? Text(l.libraryDetailsUnavailable)
            : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: ListView(
                    key: const PageStorageKey('work-editor'),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    children: [
                      Text(l.worksSelected(widget.files.length)),
                      Text(l.worksBatchNotice),
                      const SizedBox(height: 16),
                      if (!preview) ...[
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            workAction(
                              l.worksChooseExisting,
                              busy ? null : choose,
                            ),
                            workAction(
                              l.worksCreateSeparate,
                              busy ? null : () => setState(() => target = null),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (target != null)
                          Text(
                            '${target!.title} · ${target!.year ?? l.worksUnknownYear}',
                          )
                        else ...[
                          field(
                            'work-title',
                            l.mediaTitle,
                            title,
                            (v) => title = v,
                          ),
                          field(
                            'work-year',
                            l.mediaYear,
                            year,
                            (v) => year = v,
                            numeric: true,
                          ),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final option in [
                                MediaKind.movie,
                                MediaKind.series,
                              ])
                                workAction(
                                  option == MediaKind.movie
                                      ? l.mediaMovie
                                      : l.mediaSeries,
                                  () => setState(() => kind = option),
                                  selected: kind == option,
                                ),
                            ],
                          ),
                        ],
                        for (final file in widget.files)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(file.fileName),
                                Text(
                                  widget.viewModel.sourceTitle(file.sourceId),
                                ),
                                if (work.kind == MediaKind.series) ...[
                                  field(
                                    'season-${file.versionKey}',
                                    l.mediaSeason,
                                    seasons[file.versionKey]!,
                                    (v) => seasons[file.versionKey] = v,
                                    numeric: true,
                                  ),
                                  field(
                                    'episode-${file.versionKey}',
                                    l.mediaEpisode,
                                    episodes[file.versionKey]!,
                                    (v) => episodes[file.versionKey] = v,
                                    numeric: true,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        if (invalid)
                          Semantics(
                            liveRegion: true,
                            child: Text(l.mediaEditInvalid),
                          ),
                        workAction(l.worksPreview, prepare),
                      ] else ...[
                        Text(
                          '${work.title} · ${work.year ?? l.worksUnknownYear}',
                          style: context.theme.typography.body.lg,
                        ),
                        for (var i = 0; i < widget.files.length; i++)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(widget.files[i].fileName),
                                Text(
                                  widget.viewModel.sourceTitle(
                                    widget.files[i].sourceId,
                                  ),
                                ),
                                Text(
                                  work.kind == MediaKind.series
                                      ? l.worksEpisode(
                                          edits[i].season!,
                                          edits[i].episode!,
                                        )
                                      : l.mediaMovie,
                                ),
                              ],
                            ),
                          ),
                        workAction(l.worksConfirmAssign, busy ? null : save),
                        const SizedBox(height: 8),
                        workAction(
                          l.worksBackToEdit,
                          busy ? null : () => setState(() => preview = false),
                        ),
                      ],
                      if (busy)
                        Semantics(liveRegion: true, child: Text(l.worksSaving)),
                      if (failed)
                        Semantics(
                          liveRegion: true,
                          child: Text(l.mediaEditError),
                        ),
                    ],
                  ),
                ),
              ),
      );
    },
  );
}
