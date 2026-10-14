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
  String get libraryEmptyDescription => '从你已有权限的 Telegram 频道或群添加媒体，在这里浏览电影与剧集。';

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
  String get connectionUnavailable => 'Telegram 连接暂不可用；默认服务无需填写地址或令牌。';

  @override
  String get telegram => 'Telegram';

  @override
  String get notConnected => '未连接';

  @override
  String get relayService => '中转服务';

  @override
  String get notConfigured => '未配置';

  @override
  String get sourcesTitle => '来源';

  @override
  String get openSources => '了解媒体来源';

  @override
  String get sourcesEmptyTitle => '片库从来源开始';

  @override
  String get sourcesEmptyDescription =>
      '只选择你已有权限的频道或群。当前尚未连接 Telegram，没有导入任何媒体。';

  @override
  String get connectionDetails => '查看连接状态';

  @override
  String get defaultService => '默认服务';

  @override
  String get serviceUnavailable => '暂不可用';

  @override
  String get appearanceTitle => '外观';

  @override
  String get localSettingDescription => '仅保存在本机，重新打开仍然生效。';

  @override
  String get themeSystem => '跟随系统';

  @override
  String get themeLight => '浅色';

  @override
  String get themeDark => '深色';

  @override
  String get loadingSettings => '正在读取本机设置…';

  @override
  String get savingSettings => '正在保存…';

  @override
  String get loadSettingsError => '本机设置读取失败，原记录已保留。请重试。';

  @override
  String get saveSettingsError => '外观未保存，请重新选择后重试。';

  @override
  String get retry => '重试';

  @override
  String get aboutSection => '关于与隐私';

  @override
  String get localDataTitle => '本机数据说明';

  @override
  String get back => '返回';

  @override
  String get localDataHeading => '数据留在你手中';

  @override
  String get localDataBody =>
      '当前版本在本机保存外观设置。Windows 开发联调会复用独立的本机 Telegram 会话和媒体缓存，播放器只读取私有本机媒体源；应用内登录和片库导入尚未接入。卸载应用或清理浏览器站点数据会移除外观设置，开发会话与缓存需单独清理。';

  @override
  String get mediaRightsHeading => '使用你有权使用的媒体';

  @override
  String get mediaRightsBody =>
      '能访问频道或群，不代表拥有其中影片的使用权。请遵守内容授权与来源规则；TG Cine 不提供影片内容。';

  @override
  String get unofficialNotice => 'TG Cine 是独立开源项目，与 Telegram 官方无隶属关系。';

  @override
  String get selectedVideo => '所选 Telegram 视频';

  @override
  String get openSelectedVideo => '播放所选视频';

  @override
  String get developmentSelectedNotice => '本机开发媒体入口：播放终端中已选择的视频。';

  @override
  String get developmentPlaybackNotice =>
      'Windows 开发联调：播放本机终端已选择的授权媒体。应用内登录与来源选择尚未接入，长片定位仍可能缓冲。';

  @override
  String get playbackLoading => '正在准备视频…';

  @override
  String get playbackBuffering => '正在缓冲，播放将在数据就绪后继续…';

  @override
  String get playbackError => '视频暂时无法播放。请确认本机媒体服务仍在运行，再重试。';

  @override
  String get playbackPlaying => '正在播放';

  @override
  String get playbackPaused => '已暂停';

  @override
  String get playbackCompleted => '播放结束';

  @override
  String get playbackProgress => '播放进度';

  @override
  String get playbackPause => '暂停';

  @override
  String get playbackPlay => '播放';

  @override
  String get playbackReplay => '重新播放';

  @override
  String get playbackBackward => '后退 10 秒';

  @override
  String get playbackForward => '前进 10 秒';
}
