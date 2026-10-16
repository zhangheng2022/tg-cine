import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tg_cine/data/repositories/tdlib_telegram_repository.dart';
import 'package:tg_cine/data/services/telegram/mobile_telegram.dart';
import 'package:tg_cine/data/services/telegram/tdlib_probe.dart';
import 'package:tg_cine/domain/models/telegram_account.dart';

// Use --no-uninstall with an existing login. Logs contain no account/source data.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const apiId = String.fromEnvironment('TG_CINE_API_ID');
  const apiHash = String.fromEnvironment('TG_CINE_API_HASH');
  testWidgets(
    'real native login restores after a connection failure and loads sources',
    (tester) async {
      var failFirstOpen = true;
      final repository = TdlibTelegramRepository(() async {
        if (failFirstOpen) {
          failFirstOpen = false;
          throw const TelegramException(TelegramFailure.connection);
        }
        debugPrint('Source acceptance: opening native session');
        final native = await openNativeTelegram(
          jsonEncode({'apiId': int.parse(apiId), 'apiHash': apiHash}),
          defaultService: true,
        );
        debugPrint('Source acceptance: native session opened');
        return TelegramConnection(
          request: (request) async {
            final type = request['@type'];
            try {
              final result = await native.request(request);
              if (type != 'getChat') {
                debugPrint('Source RPC: $type -> ${result['@type']}');
              }
              return result;
            } catch (error) {
              debugPrint(
                'Source RPC: $type failed ${error is TdlibRequestError ? error.code : error.runtimeType}',
              );
              rethrow;
            }
          },
          events: native.events,
          readSources: native.readSources,
          writeSources: native.writeSources,
          close: native.close,
          media: native.media,
          waitForLogout: native.waitForLogout,
        );
      });
      try {
        await expectLater(
          repository.connect(),
          throwsA(isA<TelegramException>()),
        );
        expect(repository.account.stage, TelegramStage.failed);
        await repository.connect();
        expect(repository.account.stage, TelegramStage.ready);
        final page = await repository.loadSources();
        expect(page.sources.isNotEmpty, isTrue);
        debugPrint(
          'Source acceptance: choices=${page.sources.length}, hasMore=${page.hasMore}, saved=${repository.account.selectedSources.length}',
        );
      } finally {
        await repository.close();
      }
    },
    timeout: const Timeout(Duration(minutes: 4)),
    skip:
        !(Platform.isAndroid || Platform.isIOS) ||
        apiId.isEmpty ||
        apiHash.isEmpty,
  );
}
