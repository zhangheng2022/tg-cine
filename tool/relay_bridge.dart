import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:tg_cine/data/services/relay/relay_bridge.dart';
import 'package:tg_cine/data/services/relay/telegram_target_policy.dart';

Future<void> main(List<String> arguments) async {
  if (arguments.length != 1) {
    stderr.writeln(
      'Usage: dart run tool/relay_bridge.dart <local-config.json>',
    );
    exitCode = 64;
    return;
  }
  RelayBridge? bridge;
  try {
    bridge = await startConfiguredBridge(arguments.single);
    stdout.writeln(
      'Native feasibility bridge: SOCKS5 127.0.0.1:${bridge.port}',
    );
    stdout.writeln('No-auth loopback only. Press Ctrl+C to close.');
    await ProcessSignal.sigint.watch().first;
  } catch (_) {
    stderr.writeln(
      'Bridge failed. Check the local config, token file and relay availability; sensitive details omitted.',
    );
    exitCode = 1;
  } finally {
    await bridge?.close();
  }
}

Future<RelayBridge> startConfiguredBridge(String path) async {
  final config = jsonDecode(await File(path).readAsString());
  final targets = <(String, int), String>{};
  for (final entry in config['targets'] as List) {
    final address = (entry['hostname'] as String, entry['port'] as int);
    if (targets.containsKey(address)) {
      throw const FormatException('Duplicate target');
    }
    final target = encodeTelegramTarget(address.$1, address.$2);
    if (target == null) throw const FormatException('Invalid Telegram target');
    targets[address] = target;
  }
  final tokenFile = Platform.environment['TG_CINE_RELAY_TOKEN_FILE'];
  if (tokenFile == null) throw const FormatException('Token file required');
  return RelayBridge.start(
    relay: Uri.parse(config['relay'] as String),
    token: (await File(tokenFile).readAsString()).trim(),
    targets: targets,
  );
}
