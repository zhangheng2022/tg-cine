import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tg_cine/data/repositories/local_settings_repository.dart';
import 'package:tg_cine/domain/models/app_settings.dart';

void main() {
  test(
    'round trips settings with version; leaves unrelated values intact',
    () async {
      final preferences = _Preferences();
      preferences.values['other'] = 'untouched';
      final store = LocalSettingsRepository(preferences);
      expect((await store.load()).appearance, AppAppearance.system);
      await store.save(const AppSettings(appearance: AppAppearance.dark));
      expect(
        (await LocalSettingsRepository(preferences).load()).appearance,
        AppAppearance.dark,
      );
      expect(preferences.values['other'], 'untouched');
    },
  );
  for (final value in [
    'invalid json',
    '{"version":2,"appearance":"light"}',
    '{"version":1,"appearance":"unknown"}',
    '[]',
  ]) {
    test('rejects and preserves unreadable record $value', () async {
      final preferences = _Preferences()
        ..values[LocalSettingsRepository.key] = value;
      await expectLater(
        LocalSettingsRepository(preferences).load(),
        throwsFormatException,
      );
      expect(preferences.values[LocalSettingsRepository.key], value);
    });
  }
}

class _Preferences extends Fake implements SharedPreferencesAsync {
  final values = <String, String>{};
  @override
  Future<String?> getString(String key) async => values[key];
  @override
  Future<void> setString(String key, String value) async {
    values[key] = value;
  }
}
