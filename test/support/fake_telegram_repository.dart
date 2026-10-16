import 'dart:async';

import 'package:tg_cine/domain/models/local_media.dart';
import 'package:tg_cine/domain/ports/media_playback_repository.dart';

import 'package:tg_cine/domain/models/telegram_account.dart';
import 'package:tg_cine/domain/ports/telegram_repository.dart';

class FakeTelegramRepository implements TelegramRepository {
  FakeTelegramRepository({
    this.restored = false,
    this.defaultService = false,
    Set<int>? persisted,
  }) : persisted = persisted ?? {};
  final bool restored;
  final bool defaultService;
  final Set<int> persisted;
  final _events = StreamController<TelegramAccount>.broadcast(sync: true);
  TelegramAccount _account = TelegramAccount(stage: TelegramStage.disconnected);
  bool closed = false;
  bool saveFails = false;
  int loads = 0;
  final submitted = <String>[];

  void emit(TelegramAccount value) {
    _account = TelegramAccount(
      stage: value.stage,
      id: value.id,
      failure: value.failure,
      selectedSources: value.selectedSources,
      defaultService: defaultService,
      relayReady:
          defaultService &&
          ![
            TelegramStage.failed,
            TelegramStage.disconnected,
            TelegramStage.connecting,
          ].contains(value.stage),
    );
    _events.add(_account);
  }

  @override
  TelegramAccount get account => _account;
  @override
  Stream<TelegramAccount> get accounts => _events.stream;
  @override
  Future<void> connect() async => emit(
    TelegramAccount(
      stage: restored ? TelegramStage.ready : TelegramStage.phone,
      id: restored ? 100 : null,
      selectedSources: persisted,
    ),
  );
  @override
  Future<void> submit(String input) async {
    submitted.add(input);
    emit(
      TelegramAccount(
        stage: switch (account.stage) {
          TelegramStage.phone => TelegramStage.code,
          TelegramStage.code => TelegramStage.password,
          _ => TelegramStage.ready,
        },
        id: account.stage == TelegramStage.password ? 100 : null,
        selectedSources: persisted,
      ),
    );
  }

  @override
  Future<TelegramSourcePage> loadSources() async {
    loads++;
    return TelegramSourcePage(
      sources: const [
        TelegramSource(id: -1, title: '设计数据 · 电影频道'),
        TelegramSource(id: -2, title: '设计数据 · 归档剧集群'),
        TelegramSource(id: 3, title: '设计数据 · 私人聊天'),
      ],
      hasMore: loads == 1,
    );
  }

  @override
  Future<void> saveSources(Set<int> ids) async {
    if (saveFails) throw const TelegramException(TelegramFailure.storage);
    persisted
      ..clear()
      ..addAll(ids);
    emit(
      TelegramAccount(
        stage: TelegramStage.ready,
        id: 100,
        selectedSources: persisted,
      ),
    );
  }

  @override
  Future<void> logout() async =>
      emit(TelegramAccount(stage: TelegramStage.disconnected));
  @override
  Future<void> close() async {
    closed = true;
    await _events.close();
  }
}

/// Offers the playback action for layout tests without starting a native decoder.
class PlaybackLayoutTelegramRepository extends FakeTelegramRepository
    implements MediaPlaybackRepository {
  PlaybackLayoutTelegramRepository({super.restored, super.persisted});
  @override
  Future<PlaybackMedia> openPlayback(LocalMedia media) async =>
      throw StateError('Layout fixture only');
}
