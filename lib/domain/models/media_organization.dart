enum MediaKind { unresolved, movie, series }

class MediaOrganization {
  const MediaOrganization({
    this.title = '',
    this.kind = MediaKind.unresolved,
    this.year,
    this.season,
    this.episode,
    this.manual = false,
  });
  final String title;
  final MediaKind kind;
  final int? year;
  final int? season;
  final int? episode;
  final bool manual;

  bool get valid =>
      title.trim().isNotEmpty &&
      title.length <= 300 &&
      (year == null || (year! >= 1888 && year! <= 2100)) &&
      (kind == MediaKind.movie
          ? season == null && episode == null
          : kind == MediaKind.series &&
                season != null &&
                season! >= 0 &&
                season! <= 999 &&
                episode != null &&
                episode! > 0 &&
                episode! <= 9999);

  // shortcut: recognize explicit year or season/episode filenames; ambiguous names stay unresolved until corrected.
  factory MediaOrganization.parse(String fileName) {
    final name = fileName.replaceFirst(RegExp(r'\.[a-zA-Z0-9]{2,5}$'), '');
    final episode =
        RegExp(
          r'\bS(\d{1,3})[ ._-]*E(\d{1,4})\b',
          caseSensitive: false,
        ).firstMatch(name.replaceAll('_', ' ')) ??
        RegExp(r'第(\d{1,3})季[ ._-]*第?(\d{1,4})集').firstMatch(name);
    final year = RegExp(r'(?<!\d)(19\d{2}|20\d{2})(?!\d)').firstMatch(name);
    if (episode == null && year == null) return const MediaOrganization();
    final marker = episode == null
        ? year!.start
        : year == null
        ? episode.start
        : (episode.start < year.start ? episode.start : year.start);
    final title = name
        .substring(0, marker)
        .replaceAll(RegExp(r'[._]+'), ' ')
        .replaceAll(RegExp(r'[\[\]()（）\-\s]+$'), '')
        .trim();
    final value = MediaOrganization(
      title: title,
      kind: episode == null ? MediaKind.movie : MediaKind.series,
      year: year == null ? null : int.parse(year.group(1)!),
      season: episode == null ? null : int.parse(episode.group(1)!),
      episode: episode == null ? null : int.parse(episode.group(2)!),
    );
    return value.valid ? value : const MediaOrganization();
  }
}
