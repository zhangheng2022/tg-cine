import 'package:flutter/foundation.dart';

import '../../../../domain/models/app_settings.dart';
import '../../../../domain/ports/settings_repository.dart';

class SettingsViewModel extends ChangeNotifier {
  SettingsViewModel(this._repository);

  final SettingsRepository _repository;
  AppSettings _settings = const AppSettings();
  bool _loading = true;
  bool _saving = false;
  bool _loadFailed = false;
  bool _saveFailed = false;
  bool _disposed = false;

  AppAppearance get appearance => _settings.appearance;
  bool get loading => _loading;
  bool get saving => _saving;
  bool get loadFailed => _loadFailed;
  bool get saveFailed => _saveFailed;

  Future<void> load() async {
    if (_disposed || _saving) return;
    _loading = true;
    _loadFailed = false;
    notifyListeners();
    try {
      final settings = await _repository.load();
      if (!_disposed) _settings = settings;
    } catch (_) {
      if (!_disposed) _loadFailed = true;
    } finally {
      if (!_disposed) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> setAppearance(AppAppearance appearance) async {
    if (_disposed ||
        _loading ||
        _loadFailed ||
        _saving ||
        appearance == this.appearance) {
      return;
    }
    _saving = true;
    _saveFailed = false;
    notifyListeners();
    final settings = AppSettings(appearance: appearance);
    try {
      await _repository.save(settings);
      if (!_disposed) _settings = settings;
    } catch (_) {
      if (!_disposed) _saveFailed = true;
    } finally {
      if (!_disposed) {
        _saving = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
