import '../models/media_organization.dart';
import '../models/local_media.dart';
import '../models/watch_record.dart';
import '../models/media_work.dart';

abstract interface class LocalMediaRepository {
  Future<Set<int>> readSources(int accountId);
  Future<void> saveSources(int accountId, Set<int> sourceIds);
  Future<void> describeSources(int accountId, Map<int, String> titles);
  Future<List<SourceImport>> loadImports(int accountId);
  Future<ImportCheckpoint> checkpoint(int accountId, int sourceId);
  Future<ImportCheckpoint> writeBatch(
    int accountId,
    int sourceId,
    List<LocalMedia> media, {
    required int nextMessageId,
    required int expectedRevision,
    bool complete = false,
    int newestMessageId = 0,
  });
  Future<ImportCheckpoint> setPaused(
    int accountId,
    int sourceId,
    bool paused, {
    required int expectedRevision,
  });
  Future<List<LocalMedia>> loadMedia(
    int accountId, {
    int offset = 0,
    int limit = 100,
    String query = '',
    MediaKind? kind,
  });
  Future<List<LocalMedia>> loadVersions(
    int accountId,
    int sourceId,
    int messageId,
  );
  Future<void> removeSource(int accountId, int sourceId);
  Future<void> saveProgress(
    int accountId,
    String versionKey,
    Duration position, {
    bool completed = false,
    Duration duration = Duration.zero,
  });
  Future<Duration?> loadProgress(int accountId, String versionKey);
  Future<List<WatchRecord>> loadHistory(
    int accountId, {
    int offset = 0,
    int limit = 50,
    bool unfinished = false,
    int? workId,
    List<String>? versionKeys,
  });
  Future<void> removeHistory(int accountId, {String? versionKey});
  Future<UpdateCheckpoint> updateCheckpoint(int accountId, int sourceId);
  Future<void> writeUpdateBatch(
    int accountId,
    int sourceId,
    List<LocalMedia> media, {
    required int expectedRevision,
    required UpdateCheckpoint checkpoint,
  });
  Future<void> saveOrganization(
    int accountId,
    String versionKey,
    MediaOrganization? value,
  );
  Future<void> close();
  Future<List<MediaWork>> loadWorks(
    int accountId, {
    String query = '',
    int offset = 0,
    int limit = 50,
  });
  Future<List<LocalMedia>> loadWorkFiles(
    int accountId,
    int workId, {
    int offset = 0,
    int limit = 50,
    String? nextAfter,
  });
  Future<void> assignWork(
    int accountId,
    MediaWork work,
    List<WorkFileEdit> files,
  );
  Future<void> unassignWork(int accountId, List<String> versionKeys);
}
