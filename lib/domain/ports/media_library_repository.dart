import '../models/media_organization.dart';
import '../models/local_media.dart';
import '../models/watch_record.dart';
import '../models/media_work.dart';

abstract interface class MediaLibraryRepository {
  Future<List<LocalMedia>> media({
    int offset = 0,
    int limit = 50,
    String query = '',
    MediaKind? kind,
  });
  Future<List<SourceImport>> imports();
  Future<void> importNext(int sourceId);
  Future<void> pauseImport(int sourceId, bool paused);
  Future<String> messageLink(LocalMedia media);
  Future<List<WatchRecord>> history({
    int offset = 0,
    int limit = 50,
    bool unfinished = false,
    int? workId,
    List<String>? versionKeys,
  });
  Future<void> removeHistory({String? versionKey});
  Future<void> saveOrganization(LocalMedia media, MediaOrganization? value);
  Future<bool> updateNext(int sourceId);
  Future<List<MediaWork>> works({
    String query = '',
    int offset = 0,
    int limit = 50,
  });
  Future<List<LocalMedia>> workFiles(
    int workId, {
    int offset = 0,
    int limit = 50,
    String? nextAfter,
  });
  Future<void> assignWork(MediaWork work, List<WorkFileEdit> files);
  Future<void> unassignWork(List<String> versionKeys);
}
