import '../models/local_media.dart';

abstract interface class MediaLibraryRepository {
  Future<List<LocalMedia>> media({
    int offset = 0,
    int limit = 50,
    String query = '',
  });
  Future<List<SourceImport>> imports();
  Future<void> importNext(int sourceId);
  Future<void> pauseImport(int sourceId, bool paused);
  Future<String> messageLink(LocalMedia media);
}
