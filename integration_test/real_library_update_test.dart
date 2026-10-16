import 'dart:io';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tg_cine/data/repositories/tdlib_telegram_repository.dart';
import 'package:tg_cine/data/services/telegram/windows_telegram.dart';
import 'package:tg_cine/data/services/telegram/mobile_telegram.dart';
import 'package:tg_cine/domain/models/telegram_account.dart';

// Metadata only; no downloads, message sending, logout or private identifiers.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const config = String.fromEnvironment('TG_CINE_METADATA_CONFIG');
  const apiId = String.fromEnvironment('TG_CINE_API_ID');
  const apiHash = String.fromEnvironment('TG_CINE_API_HASH');
  final supported = Platform.isWindows
      ? config.isNotEmpty
      : (Platform.isAndroid || Platform.isIOS) &&
            apiId.isNotEmpty &&
            apiHash.isNotEmpty;
  testWidgets(
    'real metadata update preserves historical cursor and history',
    (tester) async {
      TdlibTelegramRepository create() => TdlibTelegramRepository(
        () => Platform.isWindows
            ? openWindowsTelegram(config, defaultService: true)
            : openNativeTelegram(
                jsonEncode({'apiId': int.parse(apiId), 'apiHash': apiHash}),
                defaultService: true,
              ),
      );
      var repository = create();
      try {
        await repository.connect();
        expect(
          repository.account.stage,
          TelegramStage.ready,
          reason: 'Interactive login required in the application',
        );
        final sources = await repository.imports();
        expect(
          sources.isNotEmpty,
          isTrue,
          reason: 'Select an authorized source in the application',
        );
        final before = sources.first;
        final history = (await repository.history(limit: 200))
            .map(
              (r) => (r.media.versionKey, r.position, r.completed, r.watchedAt),
            )
            .toList();
        final files = await repository.media(limit: 200);
        final manual = {
          for (final item in files)
            if (item.organization.manual)
              item.versionKey: item.organization.title,
        };
        await repository.pauseImport(before.sourceId, false);
        try {
          await repository.updateNext(before.sourceId);
          await repository.pauseImport(before.sourceId, true);
          final paused = (await repository.imports()).firstWhere(
            (s) => s.sourceId == before.sourceId,
          );
          expect(
            paused.checkpoint.nextMessageId == before.checkpoint.nextMessageId,
            isTrue,
          );
          await repository.close();
          repository = create();
          await repository.connect();
          expect(repository.account.stage, TelegramStage.ready);
          final reopened = (await repository.imports()).firstWhere(
            (s) => s.sourceId == before.sourceId,
          );
          expect(reopened.update.cursor == paused.update.cursor, isTrue);
          expect(reopened.update.highWater == paused.update.highWater, isTrue);
          expect(reopened.checkpoint.paused, isTrue);
          await repository.pauseImport(before.sourceId, false);
          await repository.updateNext(before.sourceId);
          final after = (await repository.imports()).firstWhere(
            (s) => s.sourceId == before.sourceId,
          );
          expect(
            after.checkpoint.nextMessageId == before.checkpoint.nextMessageId,
            isTrue,
          );
          expect(after.imported, greaterThanOrEqualTo(before.imported));
          expect(
            listEquals(
              (await repository.history(limit: 200))
                  .map(
                    (r) => (
                      r.media.versionKey,
                      r.position,
                      r.completed,
                      r.watchedAt,
                    ),
                  )
                  .toList(),
              history,
            ),
            isTrue,
            reason: 'Existing watch records must remain unchanged',
          );
          for (final item in await repository.media(limit: 200)) {
            if (manual.containsKey(item.versionKey)) {
              expect(
                item.organization.title == manual[item.versionKey],
                isTrue,
              );
              expect(item.organization.manual, isTrue);
            }
          }
          // Counts only: never print filenames, account IDs or source IDs.
          debugPrint(
            'Metadata acceptance: before=${before.imported}, after=${after.imported}, '
            'history=${history.length}, existingManual=${manual.length}, '
            'pending=${after.update.pending}; pause/reopen/resume preserved.',
          );
        } finally {
          await repository.pauseImport(
            before.sourceId,
            before.checkpoint.paused,
          );
        }
      } finally {
        await repository.close();
      }
    },
    timeout: const Timeout(Duration(minutes: 4)),
    skip: !supported,
  );
}
