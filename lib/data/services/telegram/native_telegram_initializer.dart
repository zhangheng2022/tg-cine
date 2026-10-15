import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../relay/relay_bridge.dart';
import 'tdlib_probe.dart';
import 'telegram_credentials.dart';

Future<void> initializeNativeTelegram({
  required TdlibProbe client,
  required RelayBridge bridge,
  required Directory directory,
  required Uint8List key,
  required TelegramCredentials credentials,
}) async {
  final initialized = await client.initialize([
    {
      '@type': 'setNetworkType',
      'type': {'@type': 'networkTypeNone'},
    },
    {
      '@type': 'addProxy',
      'proxy': {
        '@type': 'proxy',
        'server': '127.0.0.1',
        'port': bridge.port,
        'type': {'@type': 'proxyTypeSocks5', 'username': '', 'password': ''},
      },
      'enable': true,
      'comment': 'TG Cine local bridge',
    },
    {
      '@type': 'setTdlibParameters',
      'use_test_dc': false,
      'database_directory': directory.path,
      'files_directory': directory.uri.resolve('files/').toFilePath(),
      'database_encryption_key': base64Encode(key),
      'use_file_database': false,
      'use_chat_info_database': false,
      'use_message_database': false,
      'use_secret_chats': false,
      'api_id': credentials.apiId,
      'api_hash': credentials.apiHash,
      'system_language_code': 'zh',
      'device_model': 'TG Cine ${Platform.operatingSystem}',
      'system_version': Platform.operatingSystemVersion,
      'application_version': '0.1.0',
    },
  ]);
  if (initialized[0]['@type'] != 'ok' ||
      initialized[1]['@type'] != 'addedProxy' ||
      initialized[1]['is_enabled'] != true ||
      initialized[2]['@type'] != 'ok') {
    throw StateError('Telegram initialization failed');
  }
  await client.request({
    '@type': 'setNetworkType',
    'type': {'@type': 'networkTypeOther'},
  });
}
