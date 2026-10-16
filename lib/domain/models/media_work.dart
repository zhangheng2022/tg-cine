import 'media_organization.dart';

/// A local grouping, independent of Telegram messages and file versions.
class MediaWork {
  const MediaWork({
    this.id = 0,
    required this.title,
    required this.kind,
    this.year,
    this.fileCount = 0,
  });
  final int id;
  final String title;
  final MediaKind kind;
  final int? year;
  final int fileCount;
  bool get valid =>
      title.trim().isNotEmpty &&
      title.length <= 300 &&
      kind != MediaKind.unresolved &&
      (year == null || (year! >= 1888 && year! <= 2100));
}

class WorkFileEdit {
  const WorkFileEdit(this.versionKey, {this.season, this.episode});
  final String versionKey;
  final int? season;
  final int? episode;
}
