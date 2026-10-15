import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Both mobile clients keep database keys and legacy selections in the platform vault.
class MobileSession {
  MobileSession._(this.directory, this.key, this._lock, this._storage);
  final Directory directory;
  final Uint8List key;
  final RandomAccessFile _lock;
  final FlutterSecureStorage _storage;

  static Future<MobileSession> open(
    Directory directory,
    FlutterSecureStorage storage, {
    String keyName = 'tg-cine.telegram.primary.database-key.v1',
  }) async {
    await directory.create(recursive: true);
    final lockFile = File.fromUri(directory.uri.resolve('.session.lock'));
    final lock = await lockFile.open(mode: FileMode.append);
    try {
      await lock.lock(FileLock.exclusive);
      final existing = await storage.read(key: keyName);
      final Uint8List key;
      if (existing == null) {
        if ((await directory.list().toList()).any(
          (entry) => entry.path != lockFile.path,
        )) {
          throw StateError('Session exists without its key');
        }
        final random = Random.secure();
        key = Uint8List.fromList(List.generate(32, (_) => random.nextInt(256)));
        await storage.write(key: keyName, value: base64Encode(key));
      } else {
        key = base64Decode(existing);
        if (key.length != 32) throw StateError('Invalid session key');
      }
      return MobileSession._(directory, key, lock, storage);
    } catch (_) {
      await lock.close();
      rethrow;
    }
  }

  String _sourcesKey(int accountId) {
    if (accountId <= 0) throw const FormatException('Invalid account');
    return 'tg-cine.telegram.$accountId.sources.v1';
  }

  Future<Set<int>> readSources(int accountId) async {
    final raw = await _storage.read(key: _sourcesKey(accountId));
    if (raw == null) return {};
    if (raw.length > 32768) {
      throw const FormatException('Invalid source record');
    }
    final value = jsonDecode(raw);
    if (value is! Map ||
        value['schema'] != 1 ||
        value['accountId'] != accountId ||
        value['ids'] is! List) {
      throw const FormatException('Invalid source record');
    }
    final ids = value['ids'] as List;
    if (ids.length > 1000 ||
        ids.any((id) => id is! int || id == 0) ||
        ids.toSet().length != ids.length) {
      throw const FormatException('Invalid source record');
    }
    return ids.cast<int>().toSet();
  }

  Future<void> writeSources(int accountId, Set<int> ids) async {
    if (ids.length > 1000 || ids.contains(0)) {
      throw const FormatException('Invalid source record');
    }
    await _storage.write(
      key: _sourcesKey(accountId),
      value: jsonEncode({
        'schema': 1,
        'accountId': accountId,
        'ids': ids.toList(),
      }),
    );
  }

  Future<void> close() async {
    key.fillRange(0, key.length, 0);
    await _lock.close();
  }
}
