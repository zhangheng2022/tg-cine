import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tg_cine/domain/models/app_settings.dart';
import 'package:tg_cine/ui/features/settings/view_models/settings_view_model.dart';

import '../../../../support/memory_settings_repository.dart';

void main() {
  test(
    'appearance persists across model lifetimes; no duplicate writes',
    () async {
      final store = MemorySettingsRepository();
      final first = SettingsViewModel(store);
      await first.load();
      await first.setAppearance(AppAppearance.dark);
      await first.setAppearance(AppAppearance.dark);
      expect(first.appearance, AppAppearance.dark);
      expect(store.writes, 1);
      first.dispose();
      final second = SettingsViewModel(store);
      addTearDown(second.dispose);
      await second.load();
      expect(second.appearance, AppAppearance.dark);
    },
  );

  test('failed read prevents destructive writes and supports retry', () async {
    final store = MemorySettingsRepository()..failLoad = true;
    final model = SettingsViewModel(store);
    addTearDown(model.dispose);
    await model.load();
    await model.setAppearance(AppAppearance.light);
    expect(model.loadFailed, isTrue);
    expect(store.writes, 0);
    store.failLoad = false;
    await model.load();
    expect(model.loadFailed, isFalse);
    store.failSave = true;
    await model.setAppearance(AppAppearance.light);
    expect(model.saveFailed, isTrue);
    expect(model.appearance, AppAppearance.system);
    store.failSave = false;
    await model.setAppearance(AppAppearance.light);
    expect(model.saveFailed, isFalse);
    expect(model.appearance, AppAppearance.light);
  });

  test('completion after disposal does not notify or throw', () async {
    final store = _DelayedRepository();
    final model = SettingsViewModel(store);
    final loading = model.load();
    model.dispose();
    store.loaded.complete(const AppSettings());
    await loading;
  });
}

class _DelayedRepository extends MemorySettingsRepository {
  final loaded = Completer<AppSettings>();
  @override
  Future<AppSettings> load() => loaded.future;
}
