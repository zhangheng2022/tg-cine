import 'dart:io';

import 'package:tg_cine/data/repositories/tdlib_telegram_repository.dart';
import 'package:tg_cine/data/services/telegram/windows_telegram.dart';
import 'package:tg_cine/domain/models/telegram_account.dart';

/// Read-only native acceptance; never prints account IDs, titles or credentials.
Future<void> main(List<String> arguments) async {
  if (arguments.length != 1) {
    stderr.writeln(
      'Usage: dart run tool/verify_telegram_account.dart <private-config.json>',
    );
    exitCode = 64;
    return;
  }
  for (var attempt = 0; attempt < 2; attempt++) {
    final repository = TdlibTelegramRepository(
      () => openWindowsTelegram(arguments.single),
    );
    try {
      await repository.connect();
      if (repository.account.stage != TelegramStage.ready) {
        throw StateError('Interactive login is required in Flutter');
      }
      final page = await repository.loadSources();
      stdout.writeln(
        'Verified session ${attempt + 1}: getMe and main/archive listing passed; ${page.sources.length} accessible entries, more=${page.hasMore}.',
      );
    } catch (_) {
      stderr.writeln(
        'Native account verification failed; sensitive details omitted.',
      );
      exitCode = 1;
      return;
    } finally {
      await repository.close();
    }
  }
}
