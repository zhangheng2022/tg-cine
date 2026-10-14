import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/app_settings.dart';
import '../../domain/ports/settings_repository.dart';

class LocalSettingsRepository implements SettingsRepository {
  LocalSettingsRepository(this._preferences);

  final SharedPreferencesAsync _preferences;
  static const key = 'tg_cine.settings';

  @override
  Future<AppSettings> load() async {
    final raw = await _preferences.getString(key);
    if (raw == null) return const AppSettings();
    final data = jsonDecode(raw);
    if (data case {'version': 1, 'appearance': final String appearance}) {
      for (final value in AppAppearance.values) {
        if (value.name == appearance) return AppSettings(appearance: value);
      }
    }
    // Preserve unknown/corrupt records; an older client must not overwrite a newer schema.
    throw const FormatException('Unsupported local settings');
  }

  @override
  Future<void> save(AppSettings settings) => _preferences.setString(
    key,
    jsonEncode({'version': 1, 'appearance': settings.appearance.name}),
  );
}
