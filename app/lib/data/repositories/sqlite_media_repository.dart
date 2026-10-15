import 'dart:convert';

import 'package:sqlite3/sqlite3.dart';

import '../../domain/models/local_media.dart';
import '../../domain/ports/local_media_repository.dart';

/// Encrypted metadata only: no credentials, session data or downloaded media.
// shortcut: bounded synchronous batches; move imports to a background isolate if measurements show UI stalls.
class SqliteMediaRepository implements LocalMediaRepository {
  SqliteMediaRepository._(this._db);
  final Database _db;

  static SqliteMediaRepository open(String path, List<int> key) {
    if (key.length != 32 || key.any((byte) => byte < 0 || byte > 255)) {
      throw const LocalMediaException(LocalMediaFailure.invalidInput);
    }
    Database? db;
    try {
      db = sqlite3.open(path);
      // Standard SQLite silently ignores PRAGMA key, so verify the encryption build.
      if (db.select('PRAGMA cipher').isEmpty) {
        throw StateError('Encrypted SQLite is required');
      }
      final password = base64Encode(key);
      db.execute("PRAGMA key = '$password'");
      db.execute('PRAGMA foreign_keys = ON');
      final repository = SqliteMediaRepository._(db);
      repository._migrate();
      return repository;
    } catch (_) {
      db?.close();
      throw const LocalMediaException(LocalMediaFailure.storage);
    }
  }

  void _migrate() {
    final version = _db.userVersion;
    if (version > 3) throw StateError('Newer database schema');
    _transaction(() {
      if (version < 1) {
        _db.execute('''
CREATE TABLE accounts (
 id INTEGER PRIMARY KEY CHECK(id > 0), sources_migrated INTEGER NOT NULL DEFAULT 0 CHECK(sources_migrated IN (0,1))
) STRICT;
CREATE TABLE sources (
 account_id INTEGER NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
 id INTEGER NOT NULL CHECK(id != 0), selected INTEGER NOT NULL CHECK(selected IN (0,1)),
 PRIMARY KEY(account_id,id)
) STRICT;
CREATE TABLE messages (
 account_id INTEGER NOT NULL, source_id INTEGER NOT NULL, id INTEGER NOT NULL CHECK(id > 0),
 current_version TEXT NOT NULL, caption TEXT NOT NULL, sent_at INTEGER NOT NULL CHECK(sent_at >= 0),
 PRIMARY KEY(account_id,source_id,id),
 FOREIGN KEY(account_id,source_id) REFERENCES sources(account_id,id) ON DELETE CASCADE
) STRICT;
CREATE TABLE media_versions (
 account_id INTEGER NOT NULL, version_key TEXT NOT NULL, source_id INTEGER NOT NULL, message_id INTEGER NOT NULL,
 remote_unique_id TEXT NOT NULL, size_bytes INTEGER NOT NULL CHECK(size_bytes > 0),
 file_name TEXT NOT NULL, duration_seconds INTEGER NOT NULL CHECK(duration_seconds >= 0),
 PRIMARY KEY(account_id,version_key),
 FOREIGN KEY(account_id,source_id,message_id) REFERENCES messages(account_id,source_id,id) ON DELETE CASCADE
) STRICT;
CREATE TABLE import_checkpoints (
 account_id INTEGER NOT NULL, source_id INTEGER NOT NULL, next_message_id INTEGER NOT NULL CHECK(next_message_id >= 0),
 paused INTEGER NOT NULL CHECK(paused IN (0,1)), complete INTEGER NOT NULL CHECK(complete IN (0,1)),
 revision INTEGER NOT NULL CHECK(revision > 0), PRIMARY KEY(account_id,source_id),
 FOREIGN KEY(account_id,source_id) REFERENCES sources(account_id,id) ON DELETE CASCADE
) STRICT;
CREATE INDEX messages_recent ON messages(account_id,sent_at DESC,source_id,id);
''');
      }
      if (version < 2) {
        _db.execute('''
CREATE TABLE playback_progress (
 account_id INTEGER NOT NULL, version_key TEXT NOT NULL, position_ms INTEGER NOT NULL CHECK(position_ms >= 0),
 PRIMARY KEY(account_id,version_key),
 FOREIGN KEY(account_id,version_key) REFERENCES media_versions(account_id,version_key) ON DELETE CASCADE
) STRICT;
''');
      }
      if (version < 3) {
        _db.execute(
          "ALTER TABLE sources ADD COLUMN title TEXT NOT NULL DEFAULT ''",
        );
      }
      _db.userVersion = 3;
    });
  }

  T _transaction<T>(T Function() action) {
    _db.execute('BEGIN IMMEDIATE');
    try {
      final result = action();
      _db.execute('COMMIT');
      return result;
    } catch (_) {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  T _guard<T>(T Function() action) {
    try {
      return action();
    } on LocalMediaException {
      rethrow;
    } catch (_) {
      throw const LocalMediaException(LocalMediaFailure.storage);
    }
  }

  void _require(bool valid) {
    if (!valid) throw const LocalMediaException(LocalMediaFailure.invalidInput);
  }

  void _account(int accountId) => _require(accountId > 0);

  void _selection(int accountId, Set<int> ids) {
    _account(accountId);
    _require(ids.length <= 1000 && !ids.contains(0));
    _db.execute('INSERT OR IGNORE INTO accounts(id) VALUES (?)', [accountId]);
    final deselected = _db
        .select(
          'SELECT id FROM sources WHERE account_id = ? AND selected = 1',
          [accountId],
        )
        .map((row) => row['id'] as int)
        .where((id) => !ids.contains(id));
    for (final id in deselected) {
      final current = _checkpoint(accountId, id);
      _saveCheckpoint(
        accountId,
        id,
        ImportCheckpoint(
          nextMessageId: current.nextMessageId,
          paused: current.paused,
          complete: current.complete,
          revision: current.revision + 1,
        ),
      );
    }
    _db.execute('UPDATE sources SET selected = 0 WHERE account_id = ?', [
      accountId,
    ]);
    for (final id in ids) {
      _db.execute(
        '''INSERT INTO sources(account_id,id,selected) VALUES (?,?,1)
ON CONFLICT(account_id,id) DO UPDATE SET selected = 1''',
        [accountId, id],
      );
    }
    _db.execute('UPDATE accounts SET sources_migrated = 1 WHERE id = ?', [
      accountId,
    ]);
  }

  /// Legacy read is performed before any write; failed reads never mark migration complete.
  Future<Set<int>> restoreSources(
    int accountId,
    Future<Set<int>> Function(int) readLegacy,
  ) async {
    final migrated = _guard(() {
      _account(accountId);
      return _db.select('SELECT sources_migrated FROM accounts WHERE id = ?', [
            accountId,
          ]).firstOrNull?['sources_migrated'] ==
          1;
    });
    if (!migrated) {
      final Set<int> ids;
      try {
        ids = await readLegacy(accountId);
      } catch (_) {
        throw const LocalMediaException(LocalMediaFailure.storage);
      }
      _guard(
        () => _transaction(() {
          // A concurrent save wins over an older asynchronous migration read.
          final row = _db.select(
            'SELECT sources_migrated FROM accounts WHERE id = ?',
            [accountId],
          ).firstOrNull;
          if (row?['sources_migrated'] != 1) _selection(accountId, ids);
        }),
      );
    }
    return readSources(accountId);
  }

  @override
  Future<Set<int>> readSources(int accountId) async => _guard(() {
    _account(accountId);
    return _db
        .select(
          'SELECT id FROM sources WHERE account_id = ? AND selected = 1',
          [accountId],
        )
        .map((row) => row['id'] as int)
        .toSet();
  });

  @override
  Future<void> saveSources(int accountId, Set<int> sourceIds) async =>
      _guard(() => _transaction(() => _selection(accountId, sourceIds)));

  @override
  Future<void> describeSources(int accountId, Map<int, String> titles) async =>
      _guard(
        () => _transaction(() {
          _account(accountId);
          _require(titles.length <= 1000);
          for (final entry in titles.entries) {
            _require(entry.key != 0 && entry.value.length <= 4096);
            _db.execute(
              'UPDATE sources SET title = ? WHERE account_id = ? AND id = ?',
              [entry.value, accountId, entry.key],
            );
          }
        }),
      );

  @override
  Future<List<SourceImport>> loadImports(int accountId) async => _guard(() {
    _account(accountId);
    return _db
        .select(
          '''SELECT s.id,s.title,
(SELECT count(*) FROM messages m WHERE m.account_id = s.account_id AND m.source_id = s.id) AS imported
FROM sources s WHERE s.account_id = ? AND s.selected = 1 ORDER BY s.id''',
          [accountId],
        )
        .map(
          (row) => SourceImport(
            sourceId: row['id'] as int,
            title: row['title'] as String,
            imported: row['imported'] as int,
            checkpoint: _checkpoint(accountId, row['id'] as int),
          ),
        )
        .toList(growable: false);
  });

  ImportCheckpoint _checkpoint(int accountId, int sourceId) {
    _account(accountId);
    _require(sourceId != 0);
    final row = _db.select(
      'SELECT * FROM import_checkpoints WHERE account_id = ? AND source_id = ?',
      [accountId, sourceId],
    ).firstOrNull;
    return row == null
        ? const ImportCheckpoint()
        : ImportCheckpoint(
            nextMessageId: row['next_message_id'] as int,
            paused: row['paused'] == 1,
            complete: row['complete'] == 1,
            revision: row['revision'] as int,
          );
  }

  @override
  Future<ImportCheckpoint> checkpoint(int accountId, int sourceId) async =>
      _guard(() => _checkpoint(accountId, sourceId));

  ImportCheckpoint _writable(
    int accountId,
    int sourceId,
    int expectedRevision,
  ) {
    final current = _checkpoint(accountId, sourceId);
    final source = _db.select(
      'SELECT selected FROM sources WHERE account_id = ? AND id = ?',
      [accountId, sourceId],
    ).firstOrNull;
    if (source?['selected'] != 1 || current.revision != expectedRevision) {
      throw const LocalMediaException(LocalMediaFailure.conflict);
    }
    return current;
  }

  ImportCheckpoint _saveCheckpoint(
    int accountId,
    int sourceId,
    ImportCheckpoint next,
  ) {
    _db.execute(
      '''INSERT INTO import_checkpoints VALUES (?,?,?,?,?,?)
ON CONFLICT(account_id,source_id) DO UPDATE SET next_message_id = excluded.next_message_id,
paused = excluded.paused, complete = excluded.complete, revision = excluded.revision''',
      [
        accountId,
        sourceId,
        next.nextMessageId,
        next.paused ? 1 : 0,
        next.complete ? 1 : 0,
        next.revision,
      ],
    );
    return next;
  }

  @override
  Future<ImportCheckpoint> writeBatch(
    int accountId,
    int sourceId,
    List<LocalMedia> media, {
    required int nextMessageId,
    required int expectedRevision,
    bool complete = false,
  }) async => _guard(
    () => _transaction(() {
      _require(media.length <= 200 && nextMessageId >= 0);
      final current = _writable(accountId, sourceId, expectedRevision);
      if (current.paused) {
        throw const LocalMediaException(LocalMediaFailure.conflict);
      }
      for (final item in media) {
        _require(
          item.sourceId == sourceId &&
              item.messageId > 0 &&
              item.remoteUniqueId.isNotEmpty &&
              item.remoteUniqueId.length <= 4096 &&
              item.sizeBytes > 0 &&
              item.durationSeconds >= 0 &&
              item.sentAt >= 0 &&
              item.fileName.length <= 4096 &&
              item.caption.length <= 32768,
        );
        _db.execute(
          '''INSERT INTO messages VALUES (?,?,?,?,?,?)
ON CONFLICT(account_id,source_id,id) DO UPDATE SET current_version = excluded.current_version,
caption = excluded.caption, sent_at = excluded.sent_at''',
          [
            accountId,
            sourceId,
            item.messageId,
            item.versionKey,
            item.caption,
            item.sentAt,
          ],
        );
        _db.execute(
          '''INSERT INTO media_versions VALUES (?,?,?,?,?,?,?,?)
ON CONFLICT(account_id,version_key) DO UPDATE SET file_name = excluded.file_name,
duration_seconds = excluded.duration_seconds''',
          [
            accountId,
            item.versionKey,
            sourceId,
            item.messageId,
            item.remoteUniqueId,
            item.sizeBytes,
            item.fileName,
            item.durationSeconds,
          ],
        );
      }
      return _saveCheckpoint(
        accountId,
        sourceId,
        ImportCheckpoint(
          nextMessageId: nextMessageId,
          complete: complete,
          revision: current.revision + 1,
        ),
      );
    }),
  );

  @override
  Future<ImportCheckpoint> setPaused(
    int accountId,
    int sourceId,
    bool paused, {
    required int expectedRevision,
  }) async => _guard(
    () => _transaction(() {
      final current = _writable(accountId, sourceId, expectedRevision);
      return _saveCheckpoint(
        accountId,
        sourceId,
        ImportCheckpoint(
          nextMessageId: current.nextMessageId,
          paused: paused,
          complete: current.complete,
          revision: current.revision + 1,
        ),
      );
    }),
  );

  LocalMedia _media(Row row) => LocalMedia(
    sourceId: row['source_id'] as int,
    messageId: row['message_id'] as int,
    remoteUniqueId: row['remote_unique_id'] as String,
    sizeBytes: row['size_bytes'] as int,
    fileName: row['file_name'] as String,
    durationSeconds: row['duration_seconds'] as int,
    caption: row['caption'] as String,
    sentAt: row['sent_at'] as int,
  );

  @override
  Future<List<LocalMedia>> loadMedia(
    int accountId, {
    int offset = 0,
    int limit = 100,
    String query = '',
  }) async => _guard(() {
    _account(accountId);
    _require(offset >= 0 && limit > 0 && limit <= 200 && query.length <= 1000);
    return _db
        .select(
          '''SELECT v.*,m.caption,m.sent_at FROM media_versions v JOIN messages m
ON m.account_id = v.account_id AND m.current_version = v.version_key
JOIN sources s ON s.account_id = m.account_id AND s.id = m.source_id
WHERE v.account_id = ? AND s.selected = 1
AND (instr(lower(v.file_name),lower(?)) > 0 OR instr(lower(m.caption),lower(?)) > 0 OR instr(lower(s.title),lower(?)) > 0)
ORDER BY m.sent_at DESC,m.source_id,m.id LIMIT ? OFFSET ?''',
          [accountId, query, query, query, limit, offset],
        )
        .map(_media)
        .toList(growable: false);
  });

  @override
  Future<List<LocalMedia>> loadVersions(
    int accountId,
    int sourceId,
    int messageId,
  ) async => _guard(() {
    _account(accountId);
    _require(sourceId != 0 && messageId > 0);
    return _db
        .select(
          '''SELECT v.*,m.caption,m.sent_at FROM media_versions v JOIN messages m
ON m.account_id = v.account_id AND m.source_id = v.source_id AND m.id = v.message_id
WHERE v.account_id = ? AND v.source_id = ? AND v.message_id = ? ORDER BY v.version_key''',
          [accountId, sourceId, messageId],
        )
        .map(_media)
        .toList(growable: false);
  });

  @override
  Future<void> removeSource(int accountId, int sourceId) async => _guard(() {
    _account(accountId);
    _require(sourceId != 0);
    _transaction(() {
      if (_db.select('SELECT id FROM sources WHERE account_id = ? AND id = ?', [
        accountId,
        sourceId,
      ]).isEmpty) {
        return;
      }
      final current = _checkpoint(accountId, sourceId);
      _db.execute(
        'DELETE FROM messages WHERE account_id = ? AND source_id = ?',
        [accountId, sourceId],
      );
      _db.execute(
        'UPDATE sources SET selected = 0 WHERE account_id = ? AND id = ?',
        [accountId, sourceId],
      );
      // Keep the revision marker so an in-flight pre-removal batch cannot resurrect media.
      _saveCheckpoint(
        accountId,
        sourceId,
        ImportCheckpoint(revision: current.revision + 1),
      );
    });
  });

  @override
  Future<void> saveProgress(
    int accountId,
    String versionKey,
    Duration position,
  ) async => _guard(() {
    _account(accountId);
    _require(
      versionKey.isNotEmpty &&
          versionKey.length <= 32768 &&
          !position.isNegative,
    );
    _db.execute(
      '''INSERT INTO playback_progress VALUES (?,?,?)
ON CONFLICT(account_id,version_key) DO UPDATE SET position_ms = excluded.position_ms''',
      [accountId, versionKey, position.inMilliseconds],
    );
  });

  @override
  Future<Duration?> loadProgress(int accountId, String versionKey) async =>
      _guard(() {
        _account(accountId);
        final row = _db.select(
          'SELECT position_ms FROM playback_progress WHERE account_id = ? AND version_key = ?',
          [accountId, versionKey],
        ).firstOrNull;
        return row == null
            ? null
            : Duration(milliseconds: row['position_ms'] as int);
      });

  @override
  Future<void> close() async => _guard(_db.close);
}
