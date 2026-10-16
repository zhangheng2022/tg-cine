import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tg_cine/domain/models/telegram_account.dart';
import 'package:tg_cine/ui/features/sources/view_models/sources_view_model.dart';

import '../../../support/fake_telegram_repository.dart';

class DelayedSources extends FakeTelegramRepository {
  final pages = <Completer<TelegramSourcePage>>[];
  @override
  Future<TelegramSourcePage> loadSources() {
    final page = Completer<TelegramSourcePage>();
    pages.add(page);
    return page.future;
  }
}

void main() {
  test('reconnection preserves draft; reauthentication clears it', () async {
    final repo = FakeTelegramRepository(restored: true, persisted: {-1});
    final vm = SourcesViewModel(repo);
    await vm.connect();
    await Future<void>.delayed(Duration.zero);
    vm.select(-2, true);
    repo.emit(
      TelegramAccount(
        stage: TelegramStage.failed,
        failure: TelegramFailure.connection,
      ),
    );
    repo.emit(TelegramAccount(stage: TelegramStage.connecting));
    await vm.connect();
    await Future<void>.delayed(Duration.zero);
    expect(vm.selected, {-1, -2});
    expect(vm.failure, isNull);
    expect(repo.persisted, {-1});
    repo.emit(TelegramAccount(stage: TelegramStage.phone));
    await vm.connect();
    expect(vm.selected, {-1});
    await vm.close();
  });

  test(
    'old connection cannot replace new account sources or loading state',
    () async {
      final repo = DelayedSources();
      final vm = SourcesViewModel(repo);
      repo.emit(TelegramAccount(stage: TelegramStage.ready, id: 100));
      repo.emit(TelegramAccount(stage: TelegramStage.connecting));
      repo.emit(
        TelegramAccount(
          stage: TelegramStage.ready,
          id: 200,
          selectedSources: {-2},
        ),
      );
      repo.pages[0].complete(
        TelegramSourcePage(
          sources: const [TelegramSource(id: -1, title: 'old')],
          hasMore: false,
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(vm.loadingSources, isTrue);
      expect(vm.sources, isEmpty);
      repo.pages[1].completeError(
        const TelegramException(TelegramFailure.storage),
      );
      await Future<void>.delayed(Duration.zero);
      expect(vm.failure, TelegramFailure.storage);
      expect(vm.selected, {-2});
      final retry = vm.loadSources();
      repo.pages.last.complete(
        TelegramSourcePage(
          sources: const [TelegramSource(id: -2, title: 'new')],
          hasMore: false,
        ),
      );
      await retry;
      expect(vm.failure, isNull);
      expect(vm.sources.single.id, -2);
      await vm.close();
    },
  );
}
