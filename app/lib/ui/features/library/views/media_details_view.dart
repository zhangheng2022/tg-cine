import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart' show SelectableText;

import '../../../../domain/models/local_media.dart';
import '../../../../l10n/l10n.dart';
import '../view_models/library_view_model.dart';

String mediaSize(int size) {
  if (size >= 1024 * 1024 * 1024) {
    return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(1)} GiB';
  }
  return '${(size / (1024 * 1024)).toStringAsFixed(1)} MiB';
}

String mediaDuration(BuildContext context, int seconds) => seconds <= 0
    ? context.l10n.libraryUnknownDuration
    : '${seconds ~/ 3600}:${(seconds ~/ 60 % 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';

class MediaDetailsPage extends StatelessWidget {
  const MediaDetailsPage({required this.viewModel, super.key});
  final LibraryViewModel viewModel;
  @override
  Widget build(BuildContext context) => FScaffold(
    header: FHeader.nested(
      title: Text(context.l10n.libraryFileDetails),
      prefixes: [
        SizedBox(
          width: 48,
          height: 48,
          child: FHeaderAction.back(onPress: () => Navigator.of(context).pop()),
        ),
      ],
    ),
    child: ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) => viewModel.selected != null
          ? MediaDetails(
              viewModel: viewModel,
              media: viewModel.selected!,
              key: ValueKey(viewModel.selected!.versionKey),
            )
          : Center(child: Text(context.l10n.libraryDetailsUnavailable)),
    ),
  );
}

class MediaDetails extends StatefulWidget {
  const MediaDetails({required this.viewModel, required this.media, super.key});
  final LibraryViewModel viewModel;
  final LocalMedia media;
  @override
  State<MediaDetails> createState() => _MediaDetailsState();
}

class _MediaDetailsState extends State<MediaDetails> {
  bool _copying = false;
  bool _copied = false;
  bool _failed = false;
  Future<void> _copy() async {
    setState(() {
      _copying = true;
      _failed = false;
    });
    try {
      final link = await widget.viewModel.messageLink(widget.media);
      if (!mounted) return;
      await Clipboard.setData(ClipboardData(text: link));
      if (mounted) setState(() => _copied = true);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _copying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.media;
    final l10n = context.l10n;
    final typography = context.theme.typography;
    final fields = [
      (l10n.librarySource, widget.viewModel.sourceTitle(item.sourceId)),
      (l10n.libraryFileSize, mediaSize(item.sizeBytes)),
      (l10n.libraryDuration, mediaDuration(context, item.durationSeconds)),
      if (item.caption.isNotEmpty) (l10n.libraryOriginalCaption, item.caption),
    ];
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SelectableText(
            item.fileName.isEmpty ? l10n.libraryUnknownFile : item.fileName,
            style: typography.body.lg.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 28),
          for (final (label, value) in fields) ...[
            Text(
              label,
              style: typography.body.sm.copyWith(
                color: context.theme.colors.mutedForeground,
              ),
            ),
            const SizedBox(height: 6),
            SelectableText(value, style: typography.body.md),
            const SizedBox(height: 24),
          ],
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: FButton(
              variant: FButtonVariant.outline,
              onPress: _copying ? null : _copy,
              child: Text(l10n.libraryCopySource),
            ),
          ),
          if (_copied || _failed)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  _failed
                      ? l10n.librarySourceLinkError
                      : l10n.librarySourceCopied,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
