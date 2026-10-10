// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appName => 'TG Cine';

  @override
  String get libraryTab => '片库';

  @override
  String get historyTab => '记录';

  @override
  String get historyTitle => '观看记录';

  @override
  String get settingsTitle => '设置';

  @override
  String get libraryEmptyTitle => '还没有影片';

  @override
  String get libraryEmptyDescription => '连接 Telegram 后，在这里浏览你的电影与剧集。';

  @override
  String get openSettings => '前往设置';

  @override
  String get historyEmptyTitle => '从第一部影片开始';

  @override
  String get historyEmptyDescription => '观看记录会保存在这里，方便你下次继续播放。';

  @override
  String get openLibrary => '返回片库';

  @override
  String get connectionSection => '账户与连接';

  @override
  String get connectionUnavailable => '连接功能将在后续版本开放。';

  @override
  String get telegram => 'Telegram';

  @override
  String get notConnected => '未连接';

  @override
  String get relayService => '中转服务';

  @override
  String get notConfigured => '未配置';
}
