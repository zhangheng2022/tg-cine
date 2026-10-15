import 'package:tg_cine/domain/models/app_settings.dart';
import 'package:tg_cine/domain/ports/settings_repository.dart';

class MemorySettingsRepository implements SettingsRepository {
  AppSettings settings = const AppSettings();
  bool failLoad = false;
  bool failSave = false;
  int writes = 0;

  @override
  Future<AppSettings> load() async {
    if (failLoad) throw StateError('load failed');
    return settings;
  }

  @override
  Future<void> save(AppSettings settings) async {
    if (failSave) throw StateError('save failed');
    this.settings = settings;
    writes++;
  }
}
