import '../models/telegram_account.dart';

abstract interface class TelegramRepository {
  TelegramAccount get account;
  Stream<TelegramAccount> get accounts;
  Future<void> connect();
  Future<void> submit(String input);
  Future<TelegramSourcePage> loadSources();
  Future<void> saveSources(Set<int> sourceIds);
  Future<void> logout();
  Future<void> close();
}
