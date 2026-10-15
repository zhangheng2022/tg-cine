import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tg_cine/data/services/playback/development_media.dart';

void main() {
  final now = DateTime.utc(2026, 10, 13);
  String manifest(String uri, {Duration ttl = const Duration(minutes: 10)}) =>
      jsonEncode({'uri': uri, 'expiresAt': now.add(ttl).toIso8601String()});
  const path = '/abcdefghijklmnopqrstuvwxyz123456';
  test('accepts only a bounded, unexpired private loopback source', () {
    expect(
      parseDevelopmentMedia(manifest('http://127.0.0.1:8000$path'), now).port,
      8000,
    );
    for (final uri in [
      'https://example.com$path',
      'http://localhost:8000$path',
      'http://127.0.0.1$path',
      'http://127.0.0.1:0$path',
      'http://user@127.0.0.1:8000$path',
      'http://127.0.0.1:8000$path?token=x',
      'http://127.0.0.1:8000$path#x',
      'http://127.0.0.1:8000/video',
      'http://[::1]:8000$path',
    ]) {
      expect(
        () => parseDevelopmentMedia(manifest(uri), now),
        throwsFormatException,
      );
    }
    for (final ttl in [
      Duration.zero,
      const Duration(minutes: -1),
      const Duration(minutes: 21),
    ]) {
      expect(
        () => parseDevelopmentMedia(
          manifest('http://127.0.0.1:8000$path', ttl: ttl),
          now,
        ),
        throwsFormatException,
      );
    }
    for (final invalid in [
      '[]',
      '{}',
      '{"uri":1}',
      List.filled(4097, 'x').join(),
    ]) {
      expect(() => parseDevelopmentMedia(invalid, now), throwsFormatException);
    }
  });
}
