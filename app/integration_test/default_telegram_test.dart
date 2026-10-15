import 'dart:io';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tg_cine/app/application.dart';
import 'package:tg_cine/data/services/telegram/mobile_telegram.dart';
import 'package:tg_cine/domain/models/telegram_account.dart';
import 'package:tg_cine/ui/features/sources/views/sources_view.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'real default relay and bundled TDLib reach the phone authorization form',
    (tester) async {
      const apiId = String.fromEnvironment('TG_CINE_API_ID');
      const apiHash = String.fromEnvironment('TG_CINE_API_HASH');
      final connection = await openNativeTelegram(
        jsonEncode({'apiId': int.parse(apiId), 'apiHash': apiHash}),
        defaultService: true,
      );
      try {
        final proxies = await connection.request({'@type': 'getProxies'});
        final enabled = (proxies['proxies'] as List)
            .cast<Map<String, dynamic>>()
            .singleWhere((proxy) => proxy['is_enabled'] == true);
        expect((enabled['proxy'] as Map)['server'], '127.0.0.1');
        final ping = await connection.request({
          '@type': 'pingProxy',
          'proxy': enabled['proxy'],
        });
        expect(ping['@type'], 'seconds');
      } finally {
        await connection.close();
      }
      await tester.pumpWidget(const Application());
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(FLucideIcons.folderOpen).last);
      await tester.pumpAndSettle();
      final model = tester
          .widget<SourcesView>(find.byType(SourcesView))
          .viewModel;
      expect(model, isNotNull);
      for (
        var attempt = 0;
        attempt < 90 &&
            ![
              TelegramStage.phone,
              TelegramStage.failed,
            ].contains(model!.account.stage);
        attempt++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
        await tester.pump();
      }
      expect(model!.failure, isNull);
      expect(model.account.defaultService, isTrue);
      expect(model.account.relayReady, isTrue);
      expect(model.account.stage, TelegramStage.phone);
      expect(find.text('国际格式手机号'), findsOneWidget);
      expect(
        tester.widget<EditableText>(find.byType(EditableText)).controller.text,
        isEmpty,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
    skip: !(Platform.isAndroid || Platform.isIOS),
  );
}
