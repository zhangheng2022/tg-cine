import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../domain/models/telegram_account.dart';

import '../../repositories/tdlib_telegram_repository.dart';
import '../../repositories/sqlite_media_repository.dart';
import '../relay/relay_bridge.dart';
import '../relay/public_relay_service.dart';
import '../relay/telegram_target_policy.dart';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'tdlib_probe.dart';
import 'telegram_credentials.dart';
import 'windows_session.dart';
import 'windows_source_store.dart';
import 'native_telegram_initializer.dart';

Future<TelegramConnection> openWindowsTelegram(
  String path, {
  bool defaultService = false,
}) async {
  WindowsSession? session;
  WindowsSession? mediaSession;
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
    final file = File(path);
    if (await file.length() > 32768) {
      throw const FormatException('Invalid local configuration');
    }
    final config =
        jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    String configuredPath(String key) {
      final value = config[key];
      if (value is! String ||
          value.isEmpty ||
          !Uri.file(value).isAbsolute ||
          !RegExp(r'^(?:[a-zA-Z]:[\\/]|\\\\)').hasMatch(value)) {
        throw const FormatException('Absolute local path required');
      }
      return value;
    }

    final credentials = TelegramCredentials.parse(
      await File(configuredPath('apiEnvFile')).readAsString(),
    );
    session = await WindowsSession.open(
      Directory(configuredPath('sessionDirectory')),
      permissionsScript: File(configuredPath('permissionsScript')),
    );
    if (defaultService) {
      publicRelay = PublicRelayService(const FlutterSecureStorage());
      final relay = await publicRelay.configuration();
      await publicRelay.accessToken();
      bridge = await RelayBridge.start(
        relay: relay.relay,
        resolveTarget: publicRelay.targetFor,
        accessToken: publicRelay.accessToken,
      );
    } else {
      final relay = jsonDecode(
        await File(configuredPath('relayConfig')).readAsString(),
      ) as Map<String, dynamic>;
      final targets = <(String, int), String>{};
      for (final entry in relay['targets'] as List) {
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
        relay: Uri.parse(relay['relay'] as String),
        token: (await File(
          configuredPath('relayTokenFile'),
        ).readAsString()).trim(),
        targets: targets,
      );
    }
    try {
      client = TdlibProbe(configuredPath('library'));
    } catch (_) {
      throw const TelegramException(TelegramFailure.unavailable);
    }
    await initializeNativeTelegram(
      client: client,
      bridge: bridge,
      directory: session.directory,
      key: session.key,
      credentials: credentials,
    );
    final native = client;
    final store = WindowsSourceStore(session.directory);
    final SqliteMediaRepository localMedia;
    try {
      mediaSession = await WindowsSession.open(
        Directory(
          p.join(
            session.directory.parent.path,
            '${p.basename(p.normalize(session.directory.path))}-media',
          ),
        ),
        permissionsScript: File(configuredPath('permissionsScript')),
      );
      localMedia = media = SqliteMediaRepository.open(
        p.join(mediaSession.directory.path, 'media.db'),
        mediaSession.key,
      );
    } catch (_) {
      throw const TelegramException(TelegramFailure.storage);
    }
    return TelegramConnection(
      request: (value) =>
          native.request(value, timeout: const Duration(seconds: 45)),
      events: native.events,
      readSources: (id) => localMedia.restoreSources(id, store.read),
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
