import 'dart:io';

import 'development_media.dart';

Future<Uri> readDevelopmentMedia(String path) async {
  if (!Platform.isWindows) throw UnsupportedError('Windows development source');
  final file = File(path);
  if (await file.length() > 4096) {
    throw const FormatException('Invalid media source');
  }
  return parseDevelopmentMedia(
    await file.readAsString(),
    DateTime.now().toUtc(),
  );
}
