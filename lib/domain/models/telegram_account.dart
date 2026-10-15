enum TelegramStage {
  disconnected,
  connecting,
  phone,
  code,
  password,
  email,
  emailCode,
  ready,
  unsupported,
  failed,
}

class TelegramAccount {
  TelegramAccount({
    required this.stage,
    this.id,
    this.failure,
    this.defaultService = false,
    this.relayReady = false,
    Set<int> selectedSources = const {},
  }) : selectedSources = Set.unmodifiable(selectedSources);

  final TelegramStage stage;
  final int? id;
  final TelegramFailure? failure;
  final bool defaultService;
  final bool relayReady;
  final Set<int> selectedSources;
}

class TelegramSource {
  const TelegramSource({required this.id, required this.title});

  final int id;
  final String title;
}

class TelegramSourcePage {
  TelegramSourcePage({
    required List<TelegramSource> sources,
    required this.hasMore,
  }) : sources = List.unmodifiable(sources);

  final List<TelegramSource> sources;
  final bool hasMore;
}

enum TelegramFailure {
  invalidInput,
  authentication,
  connection,
  storage,
  unavailable,
  serviceLimited,
  linkUnsupported,
}

class TelegramException implements Exception {
  const TelegramException(this.failure);
  final TelegramFailure failure;

  @override
  String toString() => 'Telegram operation failed (${failure.name})';
}
