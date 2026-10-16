import 'package:flutter_test/flutter_test.dart';
import 'package:tg_cine/domain/models/media_organization.dart';

void main() {
  test(
    'recognizes explicit movie and episode markers, preserves ambiguous files',
    () {
      final movie = MediaOrganization.parse('Moon.River.2024.1080p.mkv');
      expect(movie.title, 'Moon River');
      expect(movie.year, 2024);
      expect(movie.kind, MediaKind.movie);
      final series = MediaOrganization.parse('山间散步_S02E03_1080p.mp4');
      expect(series.title, '山间散步');
      expect(series.season, 2);
      expect(series.episode, 3);
      expect(MediaOrganization.parse('山间散步 第2季第3集.mp4').episode, 3);
      for (final name in [
        'video.mp4',
        '1080p.mkv',
        '2024.mp4',
        'Title.S02E00.mp4',
      ]) {
        expect(MediaOrganization.parse(name).kind, MediaKind.unresolved);
      }
    },
  );
  test(
    'manual metadata rejects missing episode, invalid year and oversized title',
    () {
      expect(
        const MediaOrganization(title: 'Title', kind: MediaKind.series).valid,
        isFalse,
      );
      expect(
        const MediaOrganization(
          title: 'Title',
          kind: MediaKind.movie,
          year: -1,
        ).valid,
        isFalse,
      );
      expect(
        MediaOrganization(title: 'x' * 301, kind: MediaKind.movie).valid,
        isFalse,
      );
      expect(
        const MediaOrganization(
          title: 'Title',
          kind: MediaKind.series,
          season: 0,
          episode: 1,
        ).valid,
        isTrue,
      );
    },
  );
}
