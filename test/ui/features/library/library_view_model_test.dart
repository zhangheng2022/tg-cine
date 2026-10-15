import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tg_cine/domain/models/telegram_account.dart';
import 'package:tg_cine/ui/features/library/view_models/library_view_model.dart';

import '../../../support/fake_media_library_repository.dart';
import '../../../support/fake_telegram_repository.dart';

void main() {
  late FakeTelegramRepository telegram;
  late FakeMediaLibraryRepository repository;
  late LibraryViewModel vm;
  setUp(() async {
    telegram = FakeTelegramRepository(restored: true, persisted: {-1});
    repository = FakeMediaLibraryRepository();
    vm = LibraryViewModel(repository, telegram);
    await telegram.connect();
    await vm.refresh();
  });
  tearDown(() async {
    vm.dispose();
    await telegram.close();
  });
  test('search and selection use imported data and account changes clear private state', () async {
    expect(vm.media, hasLength(2));
    vm.select(vm.media.first);
    vm.search('山间');
    await vm.refresh();
    expect(vm.media, hasLength(1));
    telegram.emit(TelegramAccount(stage: TelegramStage.disconnected));
    expect(vm.media, isEmpty);
    expect(vm.selected, isNull);
    expect(vm.query, isEmpty);
  });
  test(
    'foreground import exposes saved media and ends on persisted completion',
    () async {
      repository.records.clear();
      repository.complete = false;
      await vm.start(-1);
      expect(repository.calls, 1);
      expect(vm.media, hasLength(2));
      expect(vm.imports.single.checkpoint.complete, isTrue);
      expect(vm.runningSource, isNull);
    },
  );
  test('background pause stops a pending batch and returning foreground does not auto-import', () async {
    repository.complete = false;
    repository.pending = Completer<void>();
    final started = vm.start(-1);
    await Future<void>.delayed(Duration.zero);
    vm.activate(false);
    await Future<void>.delayed(Duration.zero);
    expect(repository.paused, isTrue);
    repository.pending!.complete();
    await started;
    vm.activate(true);
    await vm.refresh();
    expect(repository.calls, 1);
    expect(vm.failure, isNull);
    repository.pending = null;
    await vm.start(-1);
    expect(repository.complete, isTrue);
  });
  test(
    'concurrent background and exit pauses share the pending operation',
    () async {
      repository.complete = false;
      repository.pending = Completer<void>();
      repository.pendingPause = Completer<void>();
      final started = vm.start(-1);
      await Future<void>.delayed(Duration.zero);
      vm.activate(false);
      final exitPause = vm.pause();
      expect(repository.pauseCalls, 1);
      expect(vm.pausing, isTrue);
      repository.pendingPause!.complete();
      await exitPause;
      expect(repository.paused, isTrue);
      expect(vm.pausing, isFalse);
      repository.pending!.complete();
      await started;
    },
  );
  test(
    'an old pause failure cannot restore private state after logout',
    () async {
      repository.complete = false;
      repository.pending = Completer<void>();
      repository.pendingPause = Completer<void>();
      final started = vm.start(-1);
      await Future<void>.delayed(Duration.zero);
      final paused = vm.pause();
      telegram.emit(TelegramAccount(stage: TelegramStage.disconnected));
      repository.pendingPause!.completeError(
        const TelegramException(TelegramFailure.storage),
      );
      await paused;
      repository.pending!.complete();
      await started;
      expect(vm.failure, isNull);
      expect(vm.media, isEmpty);
      expect(vm.pausing, isFalse);
    },
  );
  test('failed import retains media and supports explicit retry', () async {
    repository.complete = false;
    repository.fail = true;
    await vm.start(-1);
    expect(vm.failure, TelegramFailure.connection);
    expect(vm.media, hasLength(2));
    repository.fail = false;
    await vm.start(-1);
    expect(vm.failure, isNull);
  });
}
