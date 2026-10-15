import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../../../domain/models/telegram_account.dart';

import '../../repositories/tdlib_telegram_repository.dart';
import '../../repositories/sqlite_media_repository.dart';
import '../relay/relay_bridge.dart';
import '../relay/public_relay_service.dart';
import '../relay/telegram_target_policy.dart';
import 'mobile_session.dart';
import 'native_telegram_initializer.dart';
import 'tdlib_probe.dart';
import 'telegram_credentials.dart';

/// Native clients share session storage and the default relay credential lifecycle.
Future<TelegramConnection> openNativeTelegram(
  String configuration, {
  bool defaultService = false,
}) async {
  MobileSession? session;
  MobileSession? mediaSession;
  SqliteMediaRepository? media;
  RelayBridge? bridge;
  PublicRelayService? publicRelay;
  TdlibProbe? client;
  Future<void> cleanup() async {
    try {
      await client?.close();
    } finally {
      try {
        await bridge?.close();
        publicRelay?.close();
      } finally {
        try {
          await media?.close();
        } finally {
          try {
            await mediaSession?.close();
          } finally {
            await session?.close();
          }
        }
      }
    }
  }

  try {
    if (configuration.length > 32768) {
      throw const FormatException('Invalid configuration');
    }
    final config = jsonDecode(configuration) as Map<String, dynamic>;
    final credentials = TelegramCredentials.parse(
      'TG_API_ID=${config['apiId']}\nTG_API_HASH=${config['apiHash']}',
    );
    final support = await getApplicationSupportDirectory();
    final directory = Directory.fromUri(
      support.uri.resolve('telegram/primary/'),
    );
    await directory.create(recursive: true);
    if (Platform.isIOS) {
      await const MethodChannel('io.tgcine/native')
          .invokeMethod<void>('excludeFromBackup', directory.path);
    }
    session = await MobileSession.open(
      directory,
      const FlutterSecureStorage(
        iOptions: IOSOptions(
          accessibility: KeychainAccessibility.first_unlock_this_device,
        ),
      ),
    );
    final library = Platform.isAndroid
        ? 'libtdjson.so'
        : Platform.isWindows
        ? p.join(File(Platform.resolvedExecutable).parent.path, 'tdjson.dll')
        : await const MethodChannel('io.tgcine/native')
              .invokeMethod<String>('tdlibPath');
    if (library == null || library.isEmpty) {
      throw const TelegramException(TelegramFailure.unavailable);
    }
    // Mobile libraries are resolved by their platform loader; paths need not be absolute.
    try {
      client = TdlibProbe.load(library);
    } catch (_) {
      throw const TelegramException(TelegramFailure.unavailable);
    }
    if (defaultService) {
      publicRelay = PublicRelayService(
        const FlutterSecureStorage(
          iOptions: IOSOptions(
            accessibility: KeychainAccessibility.first_unlock_this_device,
          ),
        ),
      );
      final configuration = await publicRelay.configuration();
      await publicRelay.accessToken();
      bridge = await RelayBridge.start(
        relay: configuration.relay,
        resolveTarget: publicRelay.targetFor,
        accessToken: publicRelay.accessToken,
      );
    } else {
      final targets = <(String, int), String>{};
      for (final entry in config['targets'] as List) {
        final address = (entry['hostname'] as String, entry['port'] as int);
        if (targets.containsKey(address)) {
          throw const FormatException('Duplicate relay target');
        }
        final target = encodeTelegramTarget(address.$1, address.$2);
        if (target == null) {
          throw const FormatException('Invalid Telegram target');
        }
        targets[address] = target;
      }
      bridge = await RelayBridge.start(
        relay: Uri.parse(config['relay'] as String),
        token: config['relayToken'] as String,
        targets: targets,
      );
    }
    await initializeNativeTelegram(
      client: client,
      bridge: bridge,
      directory: session.directory,
      key: session.key,
      credentials: credentials,
    );
    final native = client;
    final accountSession = session;
    final SqliteMediaRepository localMedia;
    try {
      final mediaDirectory = Directory(
        p.join(support.path, 'media', 'primary'),
      );
      await mediaDirectory.create(recursive: true);
      if (Platform.isIOS) {
        await const MethodChannel('io.tgcine/native')
            .invokeMethod<void>('excludeFromBackup', mediaDirectory.path);
      }
      mediaSession = await MobileSession.open(
        mediaDirectory,
        const FlutterSecureStorage(
          iOptions: IOSOptions(
            accessibility: KeychainAccessibility.first_unlock_this_device,
          ),
        ),
        keyName: 'tg-cine.media.primary.database-key.v1',
      );
      localMedia = media = SqliteMediaRepository.open(
        p.join(mediaDirectory.path, 'media.db'),
        mediaSession.key,
      );
    } catch (_) {
      throw const TelegramException(TelegramFailure.storage);
    }
    return TelegramConnection(
      request: (value) =>
          native.request(value, timeout: const Duration(seconds: 45)),
      events: native.events,
      readSources: (id) =>
          localMedia.restoreSources(id, accountSession.readSources),
      writeSources: localMedia.saveSources,
      media: localMedia,
      revokeRelay: publicRelay?.revoke,
      waitForLogout: () => native.awaitState(
        'authorizationStateClosed',
        timeout: const Duration(seconds: 45),
      ),
      close: cleanup,
    );
  } catch (_) {
    await cleanup();
    rethrow;
  }
}
