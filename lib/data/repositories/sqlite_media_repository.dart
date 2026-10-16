import '../../domain/models/media_organization.dart';
import '../../domain/models/media_work.dart';

import 'dart:convert';

import 'package:sqlite3/sqlite3.dart';

import '../../domain/models/local_media.dart';
import '../../domain/models/watch_record.dart';
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
    if (version > 7) throw StateError('Newer database schema');
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
      if (version < 4) {
        _db.execute('''
ALTER TABLE playback_progress ADD COLUMN watched_at INTEGER;
ALTER TABLE playback_progress ADD COLUMN completed INTEGER NOT NULL DEFAULT 0 CHECK(completed IN (0,1));
ALTER TABLE playback_progress ADD COLUMN duration_ms INTEGER NOT NULL DEFAULT 0 CHECK(duration_ms >= 0);
CREATE INDEX progress_recent ON playback_progress(account_id,watched_at DESC,version_key);
''');
      }
      if (version < 5) {
        _db.execute('''
CREATE TABLE update_checkpoints (
 account_id INTEGER NOT NULL, source_id INTEGER NOT NULL,
 high_water INTEGER NOT NULL CHECK(high_water >= 0), cursor INTEGER NOT NULL CHECK(cursor >= 0),
 target INTEGER NOT NULL CHECK(target >= 0), checked_at INTEGER,
 PRIMARY KEY(account_id,source_id),
 FOREIGN KEY(account_id,source_id) REFERENCES sources(account_id,id) ON DELETE CASCADE
) STRICT;
INSERT INTO update_checkpoints SELECT account_id,source_id,max(id),0,0,NULL FROM messages GROUP BY account_id,source_id;
''');
      }
      if (version < 6) {
        _db.execute('''
CREATE TABLE media_organization (
 account_id INTEGER NOT NULL, version_key TEXT NOT NULL, title TEXT NOT NULL,
 kind TEXT NOT NULL CHECK(kind IN ('unresolved','movie','series')), year INTEGER, season INTEGER, episode INTEGER,
 manual INTEGER NOT NULL CHECK(manual IN (0,1)), PRIMARY KEY(account_id,version_key),
 FOREIGN KEY(account_id,version_key) REFERENCES media_versions(account_id,version_key) ON DELETE CASCADE
) STRICT;
''');
        for (var offset = 0; ; offset += 200) {
          final rows = _db.select(
            'SELECT account_id,version_key,file_name FROM media_versions ORDER BY account_id,version_key LIMIT 200 OFFSET ?',
            [offset],
          );
          for (final row in rows) {
            _writeOrganization(
              row['account_id'] as int,
              row['version_key'] as String,
              MediaOrganization.parse(row['file_name'] as String),
              manual: false,
            );
          }
          if (rows.length < 200) break;
        }
      }
      if (version < 7) {
        _db.execute('''
CREATE TABLE works (
 id INTEGER PRIMARY KEY, account_id INTEGER NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
 title TEXT NOT NULL, kind TEXT NOT NULL CHECK(kind IN ('movie','series')), year INTEGER,
 auto_key TEXT, UNIQUE(account_id,id), UNIQUE(account_id,auto_key)
) STRICT;
CREATE TABLE work_members (
 account_id INTEGER NOT NULL, version_key TEXT NOT NULL, work_id INTEGER,
 manual INTEGER NOT NULL CHECK(manual IN (0,1)), PRIMARY KEY(account_id,version_key),
 FOREIGN KEY(account_id,version_key) REFERENCES media_versions(account_id,version_key) ON DELETE CASCADE,
 FOREIGN KEY(account_id,work_id) REFERENCES works(account_id,id)
) STRICT;
CREATE INDEX work_files ON work_members(account_id,work_id,version_key);
''');
        for (var offset = 0; ; offset += 200) {
          final rows = _db.select(
            'SELECT account_id,version_key FROM media_organization ORDER BY account_id,version_key LIMIT 200 OFFSET ?',
            [offset],
          );
          for (final row in rows) {
            _syncWork(row['account_id'] as int, row['version_key'] as String);
          }
          if (rows.length < 200) break;
        }
      }
      _db.userVersion = 7;
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
            update: _updateCheckpoint(accountId, row['id'] as int),
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
    int newestMessageId = 0,
  }) async => _guard(
    () => _transaction(() {
      _require(media.length <= 200 && nextMessageId >= 0);
      final current = _writable(accountId, sourceId, expectedRevision);
      if (current.paused) {
        throw const LocalMediaException(LocalMediaFailure.conflict);
      }
      _writeMedia(accountId, sourceId, media);
      final update = _updateCheckpoint(accountId, sourceId);
      if (update.highWater == 0 && !update.pending && newestMessageId > 0) {
        _saveUpdate(
          accountId,
          sourceId,
          UpdateCheckpoint(highWater: newestMessageId),
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

  void _writeMedia(int accountId, int sourceId, List<LocalMedia> media) {
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
      _writeOrganization(
        accountId,
        item.versionKey,
        MediaOrganization.parse(item.fileName),
        manual: false,
      );
      _syncWork(accountId, item.versionKey);
    }
  }

  UpdateCheckpoint _updateCheckpoint(int accountId, int sourceId) {
    _account(accountId);
    _require(sourceId != 0);
    final row = _db.select(
      'SELECT * FROM update_checkpoints WHERE account_id = ? AND source_id = ?',
      [accountId, sourceId],
    ).firstOrNull;
    return row == null
        ? const UpdateCheckpoint()
        : UpdateCheckpoint(
            highWater: row['high_water'] as int,
            cursor: row['cursor'] as int,
            target: row['target'] as int,
            checkedAt: row['checked_at'] == null
                ? null
                : DateTime.fromMillisecondsSinceEpoch(
                    row['checked_at'] as int,
                    isUtc: true,
                  ),
          );
  }

  @override
  Future<UpdateCheckpoint> updateCheckpoint(
    int accountId,
    int sourceId,
  ) async => _guard(() => _updateCheckpoint(accountId, sourceId));

  void _saveUpdate(int accountId, int sourceId, UpdateCheckpoint value) {
    _db.execute(
      '''INSERT INTO update_checkpoints VALUES (?,?,?,?,?,?)
ON CONFLICT(account_id,source_id) DO UPDATE SET high_water = excluded.high_water,
cursor = excluded.cursor, target = excluded.target, checked_at = excluded.checked_at''',
      [
        accountId,
        sourceId,
        value.highWater,
        value.cursor,
        value.target,
        value.checkedAt?.millisecondsSinceEpoch,
      ],
    );
  }

  @override
  Future<void> writeUpdateBatch(
    int accountId,
    int sourceId,
    List<LocalMedia> media, {
    required int expectedRevision,
    required UpdateCheckpoint checkpoint,
  }) async => _guard(
    () => _transaction(() {
      final current = _writable(accountId, sourceId, expectedRevision);
      if (current.paused) {
        throw const LocalMediaException(LocalMediaFailure.conflict);
      }
      _require(
        media.length <= 200 &&
            checkpoint.highWater >= 0 &&
            checkpoint.cursor >= 0 &&
            checkpoint.target >= 0,
      );
      _writeMedia(accountId, sourceId, media);
      _saveUpdate(accountId, sourceId, checkpoint);
      _saveCheckpoint(
        accountId,
        sourceId,
        ImportCheckpoint(
          nextMessageId: current.nextMessageId,
          complete: current.complete,
          paused: current.paused,
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
    organization: MediaOrganization(
      title: row['title'] as String,
      kind: MediaKind.values.byName(row['kind'] as String),
      year: row['year'] as int?,
      season: row['season'] as int?,
      episode: row['episode'] as int?,
      manual: row['manual'] == 1,
    ),
  );

  @override
  Future<List<LocalMedia>> loadMedia(
    int accountId, {
    int offset = 0,
    int limit = 100,
    String query = '',
    MediaKind? kind,
  }) async => _guard(() {
    _account(accountId);
    _require(offset >= 0 && limit > 0 && limit <= 200 && query.length <= 1000);
    return _db
        .select(
          '''SELECT v.*,m.caption,m.sent_at,o.title,o.kind,o.year,o.season,o.episode,o.manual FROM media_versions v JOIN media_organization o ON o.account_id = v.account_id AND o.version_key = v.version_key JOIN messages m
ON m.account_id = v.account_id AND m.current_version = v.version_key
JOIN sources s ON s.account_id = m.account_id AND s.id = m.source_id
WHERE v.account_id = ? AND s.selected = 1 AND (? IS NULL OR o.kind = ?)
AND (instr(lower(v.file_name),lower(?)) > 0 OR instr(lower(m.caption),lower(?)) > 0 OR instr(lower(s.title),lower(?)) > 0 OR instr(lower(o.title),lower(?)) > 0)
ORDER BY m.sent_at DESC,m.source_id,m.id LIMIT ? OFFSET ?''',
          [
            accountId,
            kind?.name,
            kind?.name,
            query,
            query,
            query,
            query,
            limit,
            offset,
          ],
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
          '''SELECT v.*,m.caption,m.sent_at,o.title,o.kind,o.year,o.season,o.episode,o.manual FROM media_versions v JOIN media_organization o ON o.account_id = v.account_id AND o.version_key = v.version_key JOIN messages m
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
      _saveUpdate(accountId, sourceId, const UpdateCheckpoint());
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
    Duration position, {
    bool completed = false,
    Duration duration = Duration.zero,
  }) async => _guard(() {
    _account(accountId);
    _require(
      versionKey.isNotEmpty &&
          versionKey.length <= 32768 &&
          !position.isNegative &&
          !duration.isNegative,
    );
    _db.execute(
      '''INSERT INTO playback_progress(account_id,version_key,position_ms,watched_at,completed,duration_ms) VALUES (?,?,?,?,?,?)
ON CONFLICT(account_id,version_key) DO UPDATE SET position_ms = excluded.position_ms,
watched_at = excluded.watched_at, completed = excluded.completed,
duration_ms = max(playback_progress.duration_ms,excluded.duration_ms)''',
      [
        accountId,
        versionKey,
        completed ? 0 : position.inMilliseconds,
        DateTime.now().toUtc().millisecondsSinceEpoch,
        completed ? 1 : 0,
        duration.inMilliseconds,
      ],
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
  Future<List<WatchRecord>> loadHistory(
    int accountId, {
    int offset = 0,
    int limit = 50,
    bool unfinished = false,
    int? workId,
    List<String>? versionKeys,
  }) async => _guard(() {
    _account(accountId);
    _require(offset >= 0 && limit > 0 && limit <= 200);
    _require(workId == null || workId > 0);
    _require(versionKeys == null || versionKeys.length <= 200);
    if (versionKeys != null && versionKeys.isEmpty) return <WatchRecord>[];
    return _db
        .select(
          '''SELECT v.*,m.caption,m.sent_at,s.title AS source_title,o.title,o.kind,o.year,o.season,o.episode,o.manual,
p.position_ms,p.duration_ms,p.watched_at,p.completed,
(s.selected = 1 AND m.current_version = v.version_key) AS available
FROM playback_progress p JOIN media_versions v
ON v.account_id = p.account_id AND v.version_key = p.version_key
JOIN media_organization o ON o.account_id = v.account_id AND o.version_key = v.version_key
JOIN messages m ON m.account_id = v.account_id AND m.source_id = v.source_id AND m.id = v.message_id
JOIN sources s ON s.account_id = v.account_id AND s.id = v.source_id
WHERE p.account_id = ? AND (? = 0 OR (p.completed = 0 AND p.position_ms > 0))
${workId == null ? '' : '''AND s.selected=1 AND m.current_version=v.version_key
AND EXISTS (SELECT 1 FROM work_members g WHERE g.account_id=p.account_id AND g.version_key=p.version_key AND g.work_id=?)'''}
${versionKeys == null ? '' : 'AND p.version_key IN (${List.filled(versionKeys.length, '?').join(',')})'}
ORDER BY p.watched_at DESC,p.version_key LIMIT ? OFFSET ?''',
          [
            accountId,
            unfinished ? 1 : 0,
            ?workId,
            ...?versionKeys,
            limit,
            offset,
          ],
        )
        .map(
          (row) => WatchRecord(
            media: _media(row),
            sourceTitle: row['source_title'] as String,
            position: Duration(milliseconds: row['position_ms'] as int),
            duration: Duration(
              milliseconds: (row['duration_ms'] as int) > 0
                  ? row['duration_ms'] as int
                  : (row['duration_seconds'] as int) * 1000,
            ),
            watchedAt: row['watched_at'] == null
                ? null
                : DateTime.fromMillisecondsSinceEpoch(
                    row['watched_at'] as int,
                    isUtc: true,
                  ),
            completed: row['completed'] == 1,
            available: row['available'] == 1,
          ),
        )
        .toList(growable: false);
  });

  @override
  Future<void> removeHistory(
    int accountId, {
    String? versionKey,
  }) async => _guard(() {
    _account(accountId);
    _require(
      versionKey == null ||
          (versionKey.isNotEmpty && versionKey.length <= 32768),
    );
    _db.execute(
      'DELETE FROM playback_progress WHERE account_id = ?${versionKey == null ? '' : ' AND version_key = ?'}',
      [accountId, ?versionKey],
    );
  });

  void _writeOrganization(
    int accountId,
    String versionKey,
    MediaOrganization value, {
    required bool manual,
  }) {
    _db.execute(
      '''INSERT INTO media_organization VALUES (?,?,?,?,?,?,?,?)
ON CONFLICT(account_id,version_key) DO UPDATE SET title=excluded.title,kind=excluded.kind,
year=excluded.year,season=excluded.season,episode=excluded.episode,manual=excluded.manual
WHERE media_organization.manual = 0 OR ? = 1''',
      [
        accountId,
        versionKey,
        value.title,
        value.kind.name,
        value.year,
        value.season,
        value.episode,
        manual ? 1 : 0,
        manual ? 1 : 0,
      ],
    );
  }

  @override
  Future<void> saveOrganization(
    int accountId,
    String versionKey,
    MediaOrganization? value,
  ) async => _guard(
    () => _transaction(() {
      _account(accountId);
      _require(
        versionKey.isNotEmpty &&
            versionKey.length <= 32768 &&
            (value == null || value.valid),
      );
      final row = _db.select(
        'SELECT file_name FROM media_versions WHERE account_id = ? AND version_key = ?',
        [accountId, versionKey],
      ).firstOrNull;
      _require(row != null);
      if (value == null) {
        _db.execute(
          'DELETE FROM media_organization WHERE account_id = ? AND version_key = ?',
          [accountId, versionKey],
        );
      }
      _writeOrganization(
        accountId,
        versionKey,
        value ?? MediaOrganization.parse(row!['file_name'] as String),
        manual: value != null,
      );
      _syncWork(accountId, versionKey);
    }),
  );

  void _syncWork(int account, String key) {
    final row = _db.select(
      'SELECT * FROM media_organization WHERE account_id=? AND version_key=?',
      [account, key],
    ).first;
    if (_db.select(
          'SELECT manual FROM work_members WHERE account_id=? AND version_key=?',
          [account, key],
        ).firstOrNull?['manual'] ==
        1) {
      final work = _db
          .select(
            '''SELECT w.* FROM work_members g JOIN works w ON w.account_id=g.account_id AND w.id=g.work_id
WHERE g.account_id=? AND g.version_key=?''',
            [account, key],
          )
          .firstOrNull;
      if (work != null &&
          (work['title'] != row['title'] ||
              work['kind'] != row['kind'] ||
              work['year'] != row['year'])) {
        _db.execute(
          'UPDATE work_members SET work_id=NULL WHERE account_id=? AND version_key=?',
          [account, key],
        );
      }
      return;
    }
    int? id;
    if (row['kind'] != 'unresolved') {
      // shortcut: exact normalized title/kind/year only; ambiguous filenames remain separate until manually grouped.
      final auto = jsonEncode([
        row['kind'],
        (row['title'] as String).trim().toLowerCase(),
        row['year'],
      ]);
      _db.execute(
        'INSERT OR IGNORE INTO works(account_id,title,kind,year,auto_key) VALUES (?,?,?,?,?)',
        [account, row['title'], row['kind'], row['year'], auto],
      );
      id =
          _db.select('SELECT id FROM works WHERE account_id=? AND auto_key=?', [
                account,
                auto,
              ]).first['id']
              as int;
    }
    _db.execute(
      'INSERT INTO work_members VALUES (?,?,?,0) ON CONFLICT(account_id,version_key) DO UPDATE SET work_id=excluded.work_id',
      [account, key, id],
    );
  }

  @override
  Future<List<MediaWork>> loadWorks(
    int accountId, {
    String query = '',
    int offset = 0,
    int limit = 50,
  }) async => _guard(() {
    _account(accountId);
    _require(query.length <= 1000 && offset >= 0 && limit > 0 && limit <= 200);
    return _db
        .select(
          '''SELECT w.*,count(*) AS file_count FROM works w
JOIN work_members g ON g.account_id=w.account_id AND g.work_id=w.id
JOIN messages m ON m.account_id=g.account_id AND m.current_version=g.version_key
JOIN sources s ON s.account_id=m.account_id AND s.id=m.source_id AND s.selected=1
WHERE w.account_id=? AND instr(lower(w.title),lower(?))>0
GROUP BY w.id ORDER BY max(m.sent_at) DESC,w.id LIMIT ? OFFSET ?''',
          [accountId, query, limit, offset],
        )
        .map(
          (r) => MediaWork(
            id: r['id'] as int,
            title: r['title'] as String,
            kind: MediaKind.values.byName(r['kind'] as String),
            year: r['year'] as int?,
            fileCount: r['file_count'] as int,
          ),
        )
        .toList();
  });

  @override
  Future<List<LocalMedia>> loadWorkFiles(
    int accountId,
    int workId, {
    int offset = 0,
    int limit = 50,
    String? nextAfter,
  }) async => _guard(() {
    _account(accountId);
    _require(workId > 0 && offset >= 0 && limit > 0 && limit <= 200);
    int? season, episode;
    if (nextAfter != null) {
      _currentFile(accountId, nextAfter);
      final current = _db
          .select(
            '''SELECT o.season,o.episode FROM work_members g
JOIN media_organization o ON o.account_id=g.account_id AND o.version_key=g.version_key
WHERE g.account_id=? AND g.work_id=? AND g.version_key=?''',
            [accountId, workId, nextAfter],
          )
          .firstOrNull;
      _require(current != null);
      if (current!['season'] == null || current['episode'] == null) {
        return <LocalMedia>[];
      }
      final next = _db
          .select(
            '''SELECT o.season,o.episode FROM work_members g
JOIN media_organization o ON o.account_id=g.account_id AND o.version_key=g.version_key
JOIN messages m ON m.account_id=g.account_id AND m.current_version=g.version_key
JOIN sources s ON s.account_id=m.account_id AND s.id=m.source_id AND s.selected=1
WHERE g.account_id=? AND g.work_id=? AND o.season IS NOT NULL AND o.episode IS NOT NULL
AND (o.season>? OR (o.season=? AND o.episode>?))
ORDER BY o.season,o.episode LIMIT 1''',
            [
              accountId,
              workId,
              current['season'],
              current['season'],
              current['episode'],
            ],
          )
          .firstOrNull;
      if (next == null) return <LocalMedia>[];
      season = next['season'] as int;
      episode = next['episode'] as int;
    }
    return _db
        .select(
          '''SELECT v.*,m.caption,m.sent_at,o.title,o.kind,o.year,o.season,o.episode,o.manual
FROM work_members g JOIN media_versions v ON v.account_id=g.account_id AND v.version_key=g.version_key
JOIN media_organization o ON o.account_id=v.account_id AND o.version_key=v.version_key
JOIN messages m ON m.account_id=v.account_id AND m.current_version=v.version_key
JOIN sources s ON s.account_id=m.account_id AND s.id=m.source_id AND s.selected=1
WHERE g.account_id=? AND g.work_id=?
${nextAfter == null ? '' : 'AND o.season=? AND o.episode=?'}
ORDER BY o.season,o.episode,m.source_id,m.id,v.version_key LIMIT ? OFFSET ?''',
          [
            accountId,
            workId,
            if (nextAfter != null) ...[season, episode],
            limit,
            offset,
          ],
        )
        .map(_media)
        .toList();
  });

  void _currentFile(int accountId, String key) {
    _require(key.isNotEmpty && key.length <= 32768);
    if (_db
        .select(
          '''SELECT m.id FROM messages m JOIN sources s ON s.account_id=m.account_id AND s.id=m.source_id
WHERE m.account_id=? AND m.current_version=? AND s.selected=1''',
          [accountId, key],
        )
        .isEmpty) {
      throw const LocalMediaException(LocalMediaFailure.conflict);
    }
  }

  @override
  Future<void> assignWork(
    int accountId,
    MediaWork work,
    List<WorkFileEdit> files,
  ) async => _guard(
    () => _transaction(() {
      _account(accountId);
      _require(
        work.valid &&
            work.id >= 0 &&
            files.isNotEmpty &&
            files.length <= 100 &&
            files.map((f) => f.versionKey).toSet().length == files.length,
      );
      var id = work.id;
      if (id == 0) {
        _db.execute(
          'INSERT INTO works(account_id,title,kind,year) VALUES (?,?,?,?)',
          [accountId, work.title.trim(), work.kind.name, work.year],
        );
        id = _db.lastInsertRowId;
      } else {
        final row = _db.select(
          'SELECT * FROM works WHERE account_id=? AND id=?',
          [accountId, id],
        ).firstOrNull;
        _require(
          row != null &&
              row['title'] == work.title &&
              row['kind'] == work.kind.name &&
              row['year'] == work.year,
        );
      }
      for (final file in files) {
        _currentFile(accountId, file.versionKey);
        final value = MediaOrganization(
          title: work.title.trim(),
          kind: work.kind,
          year: work.year,
          season: file.season,
          episode: file.episode,
          manual: true,
        );
        _require(value.valid);
        _writeOrganization(accountId, file.versionKey, value, manual: true);
        _db.execute(
          'INSERT INTO work_members VALUES (?,?,?,1) ON CONFLICT(account_id,version_key) DO UPDATE SET work_id=excluded.work_id,manual=1',
          [accountId, file.versionKey, id],
        );
      }
    }),
  );

  @override
  Future<void> unassignWork(int accountId, List<String> versionKeys) async =>
      _guard(
        () => _transaction(() {
          _account(accountId);
          _require(
            versionKeys.isNotEmpty &&
                versionKeys.length <= 100 &&
                versionKeys.toSet().length == versionKeys.length,
          );
          for (final key in versionKeys) {
            _currentFile(accountId, key);
            // Keep an explicit override so repeated imports cannot undo a user's split.
            _db.execute(
              'INSERT INTO work_members VALUES (?,?,NULL,1) ON CONFLICT(account_id,version_key) DO UPDATE SET work_id=NULL,manual=1',
              [accountId, key],
            );
          }
        }),
      );

  @override
  Future<void> close() async => _guard(_db.close);
}
