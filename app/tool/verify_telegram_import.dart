import 'dart:io';

import 'package:tg_cine/data/repositories/tdlib_telegram_repository.dart';
import 'package:tg_cine/data/services/telegram/windows_telegram.dart';
import 'package:tg_cine/domain/models/telegram_account.dart';

/// Imports at most one metadata page from an already selected source; no private identifiers are printed.
Future<void> main(List<String> arguments) async {
  if (arguments.length != 1) {
    stderr.writeln(
      'Usage: dart run tool/verify_telegram_import.dart <private-config.json>',
    );
    exitCode = 64;
    return;
  }
  final repository = TdlibTelegramRepository(
    () => openWindowsTelegram(arguments.single),
  );
  try {
    await repository.connect();
    if (repository.account.stage != TelegramStage.ready) {
      stdout.writeln('Interactive login required.');
      exitCode = 2;
      return;
    }
    if (repository.account.selectedSources.isEmpty) {
      stdout.writeln(
        'Authorized session verified; source selection required in Flutter.',
      );
      exitCode = 2;
      return;
    }
    final before = (await repository.imports()).first;
    if (before.checkpoint.paused) {
      stdout.writeln(
        'Source is paused; resume explicitly in Flutter before verifying.',
      );
      exitCode = 2;
      return;
    }
    await repository.importNext(before.sourceId);
    final after = (await repository.imports()).first;
    stdout.writeln(
      'Metadata batch verified: saved=${after.imported}, checkpointChanged=${after.checkpoint.revision != before.checkpoint.revision}, complete=${after.checkpoint.complete}.',
    );
  } catch (_) {
    stderr.writeln(
      'Metadata import verification failed; private details omitted.',
    );
    exitCode = 1;
  } finally {
    await repository.close();
  }
}
