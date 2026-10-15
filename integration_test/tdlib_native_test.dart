import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tg_cine/data/services/telegram/tdlib_probe.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'bundled mobile TDLib exposes the modern JSON ABI and closes cleanly',
    (tester) async {
      final library = Platform.isAndroid
          ? 'libtdjson.so'
          : await const MethodChannel('io.tgcine/native')
                .invokeMethod<String>('tdlibPath');
      expect(library, isNotNull);
      final client = TdlibProbe.load(library!);
      try {
        final state = await client.request({'@type': 'getAuthorizationState'});
        expect(state['@type'], 'authorizationStateWaitTdlibParameters');
      } finally {
        await client.close();
      }
    },
    skip: !(Platform.isAndroid || Platform.isIOS),
  );
}
