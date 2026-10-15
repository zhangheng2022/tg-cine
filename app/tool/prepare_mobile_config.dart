import 'dart:convert';
import 'dart:io';

import 'package:tg_cine/data/services/telegram/telegram_credentials.dart';

/// Local developer tool; its output must only be used with flutter run --debug.
Future<void> main(List<String> arguments) async {
  if (arguments.length != 3) {
    stderr.writeln(
      'Usage: dart run tool/prepare_mobile_config.dart <api-env> <relay-config> <relay-token-file>',
    );
    exitCode = 64;
    return;
  }
  try {
    final credentials = TelegramCredentials.parse(
      await File(arguments[0]).readAsString(),
    );
    final relay = jsonDecode(
      await File(arguments[1]).readAsString(),
    ) as Map<String, dynamic>;
    final token = (await File(arguments[2]).readAsString()).trim();
    if (token.isEmpty || RegExp(r'\s').hasMatch(token)) {
      throw const FormatException('Invalid relay token');
    }
    final directory = Directory.fromUri(
      Platform.script.resolve('../../.cache/deployment/'),
    );
    await directory.create(recursive: true);
    final permissions = Platform.isWindows
        ? await Process.run('powershell.exe', [
            '-NoProfile',
            '-NonInteractive',
            '-ExecutionPolicy',
            'Bypass',
            '-File',
            Platform.script
                .resolve('support/private_directory.ps1')
                .toFilePath(),
            '-Path',
            directory.path,
          ])
        : await Process.run('chmod', ['700', directory.path]);
    if (permissions.exitCode != 0) {
      throw StateError('Configuration protection failed');
    }
    final config = jsonEncode({
      'apiId': credentials.apiId,
      'apiHash': credentials.apiHash,
      'relay': relay['relay'],
      'relayToken': token,
      'targets': relay['targets'],
    });
    final file = File.fromUri(
      directory.uri.resolve('flutter-mobile-defines.json'),
    );
    await file.writeAsString(
      jsonEncode({'TG_CINE_TELEGRAM_MOBILE_CONFIG': config}),
      flush: true,
    );
    if (!Platform.isWindows) {
      final chmod = await Process.run('chmod', ['600', file.path]);
      if (chmod.exitCode != 0) {
        throw StateError('Configuration protection failed');
      }
    }
    stdout.writeln(
      'Protected mobile Debug configuration prepared in .cache/deployment; contents omitted.',
    );
  } catch (_) {
    stderr.writeln('Mobile configuration failed; sensitive details omitted.');
    exitCode = 1;
  }
}
