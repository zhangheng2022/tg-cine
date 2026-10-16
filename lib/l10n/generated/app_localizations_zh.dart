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
  String get playbackFullscreen => '全屏播放';

  @override
  String get playbackExitFullscreen => '退出全屏';

  @override
  String get playbackHideControls => '隐藏控件';

  @override
  String get playbackShowControls => '显示播放控件';

  @override
  String get worksNoNextEpisode => '当前片库没有下一集；可返回作品查看其他文件或检查来源更新。';

  @override
  String get worksChooseNextVersion => '选择片库中下一集的文件版本';

  @override
  String get worksUnwatched => '未观看';

  @override
  String worksWatchedPosition(int minutes) {
    return '已看到 $minutes 分钟';
  }

  @override
  String get worksNextEpisode => '下一集';

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
  String get playbackError => '视频暂时无法播放。请检查网络、默认服务和来源访问权限后重试。';

  @override
  String get libraryPlay => '播放此文件';

  @override
  String get playbackProgressError => '进度未能保存。请检查本机存储，继续播放后会重试。';

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
  String get libraryImportNotice => '分批保存来源中的视频信息。可暂停后继续，检查更新只读取新消息。';

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
  String get telegramServiceLimited => '默认服务暂时限制请求，请暂停导入并稍后重试。';

  @override
  String get serviceConnected => '已连接';

  @override
  String get serviceConnecting => '连接中';

  @override
  String get telegramServiceAccessExpired => '默认服务访问已失效，请重新连接以重新启用。';

  @override
  String get historyUnknownDate => '早期记录 · 观看时间未知';

  @override
  String get historyCompleted => '已看完';

  @override
  String historyProgress(String position, String duration) {
    return '已看 $position / $duration';
  }

  @override
  String get historyUnavailable => '来源未选中或文件已被替换，请到来源页或片库确认。';

  @override
  String get historyContinue => '继续观看';

  @override
  String get historyReplay => '重新播放';

  @override
  String get historyRemove => '移除记录';

  @override
  String get historyLocalNotice => '观看记录仅保存在本机，按当前账号独立保存。';

  @override
  String get historyClearNotice => '清空后将移除本机观看记录与续播位置，片库文件和 Telegram 内容会保留。';

  @override
  String get historyConfirmClear => '确认清空记录';

  @override
  String get historyClear => '清空观看记录';

  @override
  String get cancelAction => '取消';

  @override
  String get historyError => '观看记录读取或保存失败，请重新读取后重试。';

  @override
  String get continueWatching => '继续观看';

  @override
  String get libraryCheckUpdates => '检查更新';

  @override
  String get libraryResumeUpdates => '继续检查更新';

  @override
  String get libraryCheckingUpdates => '正在检查新消息…';

  @override
  String get libraryUpdatesChecked => '已完成上次新消息检查';

  @override
  String get libraryUpdateNotice => '手动检查新消息；历史导入进度会保留。';

  @override
  String get mediaAll => '全部';

  @override
  String get mediaMovie => '电影';

  @override
  String get mediaSeries => '电视剧';

  @override
  String get mediaUnresolved => '待整理';

  @override
  String get mediaEdit => '修正影视信息';

  @override
  String get mediaTitle => '片名';

  @override
  String get mediaYear => '年份（可选）';

  @override
  String get mediaSeason => '季';

  @override
  String get mediaEpisode => '集';

  @override
  String get mediaSave => '保存信息';

  @override
  String get mediaReset => '恢复文件名识别';

  @override
  String get mediaManual => '手动修正';

  @override
  String get mediaInferred => '从文件名识别，可能需要修正';

  @override
  String get mediaUnresolvedNotice => '未能从文件名确定影视信息，可手动填写。';

  @override
  String get mediaEditInvalid =>
      '请填写片名；年份需为 1888–2100，电视剧需填写季（0–999）和集（1–9999）。';

  @override
  String get mediaEditError => '影视信息保存失败，请重试。';

  @override
  String get mediaOriginalName => '原文件名';

  @override
  String get worksTitle => '作品片库';

  @override
  String get worksOrganizeFiles => '整理文件';

  @override
  String get worksUnknownYear => '年份未知';

  @override
  String get worksSelectionNotice => '选择要整理的文件，每批最多 100 个。每个文件保留独立观看进度。';

  @override
  String worksSelected(int count) {
    return '已选择 $count 个文件';
  }

  @override
  String worksFileCount(int count) {
    return '$count 个文件版本';
  }

  @override
  String worksEpisode(int season, int episode) {
    return '第 $season 季 · 第 $episode 集';
  }

  @override
  String get worksAssign => '调整归组';

  @override
  String get worksDetach => '撤销选中归组';

  @override
  String get worksConfirmDetach => '确认撤销归组';

  @override
  String get worksDetachNotice => '选中文件将退出作品归组，仍可在整理文件中找到；原文件、影视信息和观看记录保留。';

  @override
  String get worksSelect => '选择文件';

  @override
  String get worksDeselect => '取消选择';

  @override
  String get worksEmpty => '暂无匹配条目；可在整理文件中选择文件并建立作品。';

  @override
  String get worksLoadMore => '加载更多条目';

  @override
  String get worksBatchNotice => '先确认共同片名、年份和类型，电视剧逐条确认季集；预览后整批保存。';

  @override
  String get worksChooseExisting => '选择已有作品';

  @override
  String get worksCreateSeparate => '新建独立作品';

  @override
  String get worksPreview => '预览归组';

  @override
  String get worksConfirmAssign => '确认整批保存';

  @override
  String get worksBackToEdit => '返回修改';

  @override
  String get worksSaving => '正在保存归组…';
}
