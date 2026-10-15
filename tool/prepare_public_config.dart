import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:tg_cine/data/services/telegram/telegram_credentials.dart';

/// Produces ignored application build inputs, never a shared relay credential.
Future<void> main(List<String> arguments) async {
  if (arguments.length != 1) {
    stderr.writeln(
      'Usage: dart run tool/prepare_public_config.dart <project-api-env>',
    );
    exitCode = 64;
    return;
  }
  try {
    final source = File(arguments.single);
    if (await source.length() > 32768) {
      throw const FormatException('Invalid API file');
    }
    final credentials = TelegramCredentials.parse(await source.readAsString());
    final root = Directory.fromUri(Platform.script.resolve('../'));
    final directory = Directory(p.join(root.path, '.cache', 'deployment'));
    await directory.create(recursive: true);
    final permission = Platform.isWindows
        ? await Process.run('powershell.exe', [
            '-NoProfile',
            '-NonInteractive',
            '-ExecutionPolicy',
            'Bypass',
            '-File',
            p.join(root.path, 'tool', 'support', 'private_directory.ps1'),
            '-Path',
            directory.path,
          ])
        : await Process.run('chmod', ['700', directory.path]);
    if (permission.exitCode != 0) {
      throw StateError('Build inputs protection failed');
    }
    final file = File(p.join(directory.path, 'flutter-public-defines.json'));
    await file.writeAsString(
      jsonEncode({
        'TG_CINE_API_ID': credentials.apiId.toString(),
        'TG_CINE_API_HASH': credentials.apiHash,
      }),
      flush: true,
    );
    if (!Platform.isWindows) {
      if ((await Process.run('chmod', ['600', file.path])).exitCode != 0) {
        throw StateError('Build inputs protection failed');
      }
    } else {
      final library = File(
        p.join(
          root.path,
          '.cache',
          'native',
          'build-windows',
          'Release',
          'tdjson.dll',
        ),
      );
      if (sha256.convert(await library.readAsBytes()).toString() !=
          'b516c0ee7b72a21c404aad6c2dbfaf24d2e952e840394b5172291c7f578ed3c3') {
        throw StateError('Unverified TDLib artifact');
      }
      final target = Directory(p.join(root.path, 'windows', 'TDLib'));
      await library.copy(p.join(target.path, 'tdjson.dll'));
    }
    stdout.writeln(
      'Protected public-client build inputs prepared; relay secrets excluded.',
    );
  } catch (_) {
    stderr.writeln(
      'Public build preparation failed; sensitive details omitted.',
    );
    exitCode = 1;
  }
}
