import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import '../../../../domain/models/local_media.dart';
import '../../../../domain/models/media_organization.dart';
import '../../../../l10n/l10n.dart';
import '../view_models/library_view_model.dart';

class MediaOrganizationEditor extends StatefulWidget {
  const MediaOrganizationEditor({
    required this.viewModel,
    required this.media,
    super.key,
  });
  final LibraryViewModel viewModel;
  final LocalMedia media;
  @override
  State<MediaOrganizationEditor> createState() =>
      _MediaOrganizationEditorState();
}

class _MediaOrganizationEditorState extends State<MediaOrganizationEditor> {
  bool _editing = false;
  bool _saving = false;
  bool _invalid = false;
  bool _failed = false;
  MediaOrganization? _saved;
  @override
  void didUpdateWidget(covariant MediaOrganizationEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.media != widget.media) _saved = null;
  }

  String _title = '', _year = '', _season = '', _episode = '';
  MediaKind _kind = MediaKind.movie;
  int? number(String value) =>
      value.trim().isEmpty ? null : int.tryParse(value.trim()) ?? -1;
  Future<void> _save({bool reset = false}) async {
    final value = MediaOrganization(
      title: _title.trim(),
      kind: _kind,
      year: number(_year),
      season: _kind == MediaKind.series ? number(_season) : null,
      episode: _kind == MediaKind.series ? number(_episode) : null,
      manual: true,
    );
    if (!reset && !value.valid) {
      setState(() => _invalid = true);
      return;
    }
    setState(() {
      _saving = true;
      _invalid = false;
      _failed = false;
    });
    try {
      await widget.viewModel.saveOrganization(
        widget.media,
        reset ? null : value,
      );
      if (mounted) {
        setState(() {
          _saved = reset
              ? MediaOrganization.parse(widget.media.fileName)
              : value;
          _editing = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final value = _saved ?? widget.media.organization;
    Widget button(String text, VoidCallback? action) => ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: FButton(
        mainAxisSize: MainAxisSize.min,
        variant: FButtonVariant.outline,
        onPress: _saving ? null : action,
        child: Text(text),
      ),
    );
    Widget field(
      String key,
      String label,
      String initial,
      ValueChanged<String> change, {
      bool numeric = false,
    }) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: FTextField(
        key: ValueKey(key),
        enabled: !_saving,
        label: Text(label),
        keyboardType: numeric ? TextInputType.number : TextInputType.text,
        control: FTextFieldControl.managed(
          initial: TextEditingValue(text: initial),
          onChange: (v) => change(v.text),
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!_editing) ...[
          if (value.kind == MediaKind.unresolved)
            Text(l10n.mediaUnresolvedNotice)
          else ...[
            Text(
              value.title,
              style: context.theme.typography.body.lg.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                Text(
                  value.kind == MediaKind.movie
                      ? l10n.mediaMovie
                      : l10n.mediaSeries,
                ),
                if (value.year != null) Text('${value.year}'),
                if (value.season != null)
                  Text(
                    '${l10n.mediaSeason} ${value.season} · ${l10n.mediaEpisode} ${value.episode}',
                  ),
              ],
            ),
            Text(value.manual ? l10n.mediaManual : l10n.mediaInferred),
          ],
          const SizedBox(height: 12),
          button(
            l10n.mediaEdit,
            () => setState(() {
              _title = value.title;
              _year = value.year?.toString() ?? '';
              _season = value.season?.toString() ?? '';
              _episode = value.episode?.toString() ?? '';
              _kind = value.kind == MediaKind.series
                  ? MediaKind.series
                  : MediaKind.movie;
              _editing = true;
              _invalid = false;
              _failed = false;
            }),
          ),
        ] else ...[
          field(
            'organization-title',
            l10n.mediaTitle,
            _title,
            (v) => _title = v,
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final kind in [MediaKind.movie, MediaKind.series])
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: FButton(
                    mainAxisSize: MainAxisSize.min,
                    variant: _kind == kind
                        ? FButtonVariant.primary
                        : FButtonVariant.outline,
                    onPress: _saving
                        ? null
                        : () => setState(() => _kind = kind),
                    child: Text(
                      kind == MediaKind.movie
                          ? l10n.mediaMovie
                          : l10n.mediaSeries,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          field(
            'organization-year',
            l10n.mediaYear,
            _year,
            (v) => _year = v,
            numeric: true,
          ),
          if (_kind == MediaKind.series) ...[
            field(
              'organization-season',
              l10n.mediaSeason,
              _season,
              (v) => _season = v,
              numeric: true,
            ),
            field(
              'organization-episode',
              l10n.mediaEpisode,
              _episode,
              (v) => _episode = v,
              numeric: true,
            ),
          ],
          if (_invalid)
            Semantics(liveRegion: true, child: Text(l10n.mediaEditInvalid)),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              button(l10n.mediaSave, () => _save()),
              button(l10n.cancelAction, () => setState(() => _editing = false)),
              if (value.manual)
                button(l10n.mediaReset, () => _save(reset: true)),
            ],
          ),
        ],
        if (_failed)
          Semantics(liveRegion: true, child: Text(l10n.mediaEditError)),
      ],
    );
  }
}
