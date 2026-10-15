import '../models/local_media.dart';

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
    Duration position,
  );
  Future<Duration?> loadProgress(int accountId, String versionKey);
  Future<void> close();
}
