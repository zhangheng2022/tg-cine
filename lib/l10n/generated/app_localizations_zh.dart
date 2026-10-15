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
      '外观设置、加密 Telegram 会话与片库保存在本机，来源按账号隔离。默认服务的设备访问凭据单独保存在系统安全存储。退出登录会注销会话，关闭应用会保留登录。卸载和清理数据的行为依赖平台，开发目录需单独管理。';

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
      '开发播放器仍读取本机工具提供的私有媒体源，与应用内来源选择独立；长片定位仍可能缓冲。';

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

  @override
  String get telegramConnectTitle => '连接你的 Telegram';

  @override
  String get telegramConnectBody => '使用你自己的账号，选择已有权限的媒体来源。登录后可在本机保存来源选择。';

  @override
  String get telegramConnect => '连接 Telegram';

  @override
  String get telegramConnecting => '正在连接…';

  @override
  String get telegramContinue => '继续';

  @override
  String get telegramPhone => '国际格式手机号';

  @override
  String get telegramPhoneHint => '+ 国家码和手机号';

  @override
  String get telegramCode => 'Telegram 验证码';

  @override
  String get telegramPassword => '两步验证密码';

  @override
  String get telegramEmail => '登录邮箱';

  @override
  String get telegramEmailCode => '邮箱验证码';

  @override
  String get telegramLoginPrivacy =>
      '验证码和密码仅用于本次验证，不保存在 TG Cine 设置中。Telegram 会话加密保存在本机。';

  @override
  String get telegramInvalidInput => '输入格式不正确，请检查后重试。';

  @override
  String get telegramAuthenticationError => '验证未通过，请检查验证码或密码后重试。';

  @override
  String get telegramStorageError => '本机来源记录未能保存或读取，原记录已保留。请重试。';

  @override
  String get telegramConnectionError => '连接或加载失败，请检查网络后重试。';

  @override
  String get telegramUnavailable => '当前平台的 Telegram 接入尚未就绪。';

  @override
  String get telegramUnsupportedAuth =>
      '当前登录步骤暂不支持。请使用已有 Telegram 客户端完成账号注册后重试。';

  @override
  String get telegramCancelLogin => '取消本次登录';

  @override
  String get telegramChooseSources => '选择媒体来源';

  @override
  String get telegramSourcesBody => '从主列表和归档中选择来源。';

  @override
  String get telegramSearchSources => '搜索已加载的来源';

  @override
  String get telegramNoSources => '没有匹配的来源；可调整搜索或加载更多。';

  @override
  String get telegramLoadingSources => '正在加载来源…';

  @override
  String get telegramLoadMore => '加载更多来源';

  @override
  String telegramSourcesSelected(int count) {
    return '已选择 $count 个来源';
  }

  @override
  String get telegramSaveSources => '保存选择';

  @override
  String get telegramSourcesSaved => '来源选择已保存在本机';

  @override
  String get telegramLogout => '退出登录';

  @override
  String get telegramConfirmLogout => '确认退出登录';

  @override
  String get telegramKeepLogin => '保持登录';

  @override
  String get telegramConnected => '已连接';

  @override
  String get telegramDevelopmentConnection => '本机开发接入：会话由应用持有；公共默认服务尚未开放。';

  @override
  String get telegramSourcesNote => '不按聊天类型过滤。只选择你有权使用的媒体来源；保存后可在片库开始分批导入。';

  @override
  String get librarySearch => '搜索已导入的文件、说明或来源';

  @override
  String get libraryManageSources => '管理来源';

  @override
  String get libraryImportSources => '导入来源';

  @override
  String get libraryImportNotice => '分批整理消息，不下载视频。应用切到后台时暂停；再次打开后可继续。';

  @override
  String libraryImportCount(int count) {
    return '已导入 $count 个视频';
  }

  @override
  String get libraryImportStart => '开始导入';

  @override
  String get libraryImportContinue => '继续导入';

  @override
  String get libraryImportPause => '暂停导入';

  @override
  String get libraryImportRunning => '正在整理历史消息…';

  @override
  String get libraryImportPaused => '已暂停';

  @override
  String get libraryImportComplete => '历史整理完成';

  @override
  String get libraryImportIdle => '等待导入';

  @override
  String get libraryImportError => '导入或读取未完成，已保存的内容仍保留。请重试。';

  @override
  String get libraryStorageError => '本机媒体记录暂时无法读取或保存，请重试。';

  @override
  String get libraryNoMedia => '尚无已导入的视频';

  @override
  String get libraryNoMediaBody => '从来源开始导入；首批视频保存后会出现在这里。';

  @override
  String get libraryNoResults => '没有匹配的已导入视频';

  @override
  String get libraryClearSearch => '清除搜索';

  @override
  String get libraryLoadMore => '加载更多视频';

  @override
  String get libraryRetry => '重新读取';

  @override
  String get libraryFileDetails => '文件详情';

  @override
  String get librarySelectFile => '选择一个视频查看文件信息';

  @override
  String get libraryUnknownFile => '未命名视频';

  @override
  String get libraryUnknownSource => '来源名称未加载';

  @override
  String get libraryUnknownDuration => '时长未知';

  @override
  String get libraryFileSize => '文件大小';

  @override
  String get libraryDuration => '时长';

  @override
  String get librarySource => '来源';

  @override
  String get libraryOriginalCaption => '原消息说明';

  @override
  String get libraryCopySource => '复制源消息链接';

  @override
  String get librarySourceCopied => '链接已复制，可在 Telegram 中查看';

  @override
  String get librarySourceLinkError => '暂时无法取得源消息链接，请检查来源权限后重试。';

  @override
  String get librarySourceLinkUnsupported => '这条消息不支持源链接。你仍可在原聊天中查找。';

  @override
  String get libraryDetailsUnavailable => '当前条目已不可用，请返回片库。';

  @override
  String get libraryLoading => '正在读取本机片库…';

  @override
  String get telegramDefaultConnection =>
      '默认服务自动连接。Telegram 登录会话与片库保存在本机，无需填写服务地址或访问令牌。';

  @override
  String get telegramServiceLimited => '默认服务额度或连接数已达上限，请暂停导入并稍后重试。';

  @override
  String get serviceConnected => '已连接';

  @override
  String get serviceConnecting => '连接中';

  @override
  String get telegramServiceAccessExpired => '默认服务访问已失效，请重新连接以重新启用。';
}
