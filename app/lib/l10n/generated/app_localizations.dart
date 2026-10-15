import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('zh')];

  /// No description provided for @appName.
  ///
  /// In zh, this message translates to:
  /// **'TG Cine'**
  String get appName;

  /// No description provided for @libraryTab.
  ///
  /// In zh, this message translates to:
  /// **'片库'**
  String get libraryTab;

  /// No description provided for @historyTab.
  ///
  /// In zh, this message translates to:
  /// **'记录'**
  String get historyTab;

  /// No description provided for @historyTitle.
  ///
  /// In zh, this message translates to:
  /// **'观看记录'**
  String get historyTitle;

  /// No description provided for @settingsTitle.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get settingsTitle;

  /// No description provided for @libraryEmptyTitle.
  ///
  /// In zh, this message translates to:
  /// **'还没有影片'**
  String get libraryEmptyTitle;

  /// No description provided for @libraryEmptyDescription.
  ///
  /// In zh, this message translates to:
  /// **'从你已有权限的 Telegram 频道或群添加媒体，在这里浏览电影与剧集。'**
  String get libraryEmptyDescription;

  /// No description provided for @openSettings.
  ///
  /// In zh, this message translates to:
  /// **'前往设置'**
  String get openSettings;

  /// No description provided for @historyEmptyTitle.
  ///
  /// In zh, this message translates to:
  /// **'从第一部影片开始'**
  String get historyEmptyTitle;

  /// No description provided for @historyEmptyDescription.
  ///
  /// In zh, this message translates to:
  /// **'观看记录会保存在这里，方便你下次继续播放。'**
  String get historyEmptyDescription;

  /// No description provided for @openLibrary.
  ///
  /// In zh, this message translates to:
  /// **'返回片库'**
  String get openLibrary;

  /// No description provided for @connectionSection.
  ///
  /// In zh, this message translates to:
  /// **'账户与连接'**
  String get connectionSection;

  /// No description provided for @connectionUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'Telegram 连接暂不可用；默认服务无需填写地址或令牌。'**
  String get connectionUnavailable;

  /// No description provided for @telegram.
  ///
  /// In zh, this message translates to:
  /// **'Telegram'**
  String get telegram;

  /// No description provided for @notConnected.
  ///
  /// In zh, this message translates to:
  /// **'未连接'**
  String get notConnected;

  /// No description provided for @relayService.
  ///
  /// In zh, this message translates to:
  /// **'中转服务'**
  String get relayService;

  /// No description provided for @notConfigured.
  ///
  /// In zh, this message translates to:
  /// **'未配置'**
  String get notConfigured;

  /// No description provided for @sourcesTitle.
  ///
  /// In zh, this message translates to:
  /// **'来源'**
  String get sourcesTitle;

  /// No description provided for @openSources.
  ///
  /// In zh, this message translates to:
  /// **'了解媒体来源'**
  String get openSources;

  /// No description provided for @sourcesEmptyTitle.
  ///
  /// In zh, this message translates to:
  /// **'片库从来源开始'**
  String get sourcesEmptyTitle;

  /// No description provided for @sourcesEmptyDescription.
  ///
  /// In zh, this message translates to:
  /// **'只选择你已有权限的频道或群。当前尚未连接 Telegram，没有导入任何媒体。'**
  String get sourcesEmptyDescription;

  /// No description provided for @connectionDetails.
  ///
  /// In zh, this message translates to:
  /// **'查看连接状态'**
  String get connectionDetails;

  /// No description provided for @defaultService.
  ///
  /// In zh, this message translates to:
  /// **'默认服务'**
  String get defaultService;

  /// No description provided for @serviceUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'暂不可用'**
  String get serviceUnavailable;

  /// No description provided for @appearanceTitle.
  ///
  /// In zh, this message translates to:
  /// **'外观'**
  String get appearanceTitle;

  /// No description provided for @localSettingDescription.
  ///
  /// In zh, this message translates to:
  /// **'仅保存在本机，重新打开仍然生效。'**
  String get localSettingDescription;

  /// No description provided for @themeSystem.
  ///
  /// In zh, this message translates to:
  /// **'跟随系统'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In zh, this message translates to:
  /// **'浅色'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In zh, this message translates to:
  /// **'深色'**
  String get themeDark;

  /// No description provided for @loadingSettings.
  ///
  /// In zh, this message translates to:
  /// **'正在读取本机设置…'**
  String get loadingSettings;

  /// No description provided for @savingSettings.
  ///
  /// In zh, this message translates to:
  /// **'正在保存…'**
  String get savingSettings;

  /// No description provided for @loadSettingsError.
  ///
  /// In zh, this message translates to:
  /// **'本机设置读取失败，原记录已保留。请重试。'**
  String get loadSettingsError;

  /// No description provided for @saveSettingsError.
  ///
  /// In zh, this message translates to:
  /// **'外观未保存，请重新选择后重试。'**
  String get saveSettingsError;

  /// No description provided for @retry.
  ///
  /// In zh, this message translates to:
  /// **'重试'**
  String get retry;

  /// No description provided for @aboutSection.
  ///
  /// In zh, this message translates to:
  /// **'关于与隐私'**
  String get aboutSection;

  /// No description provided for @localDataTitle.
  ///
  /// In zh, this message translates to:
  /// **'本机数据说明'**
  String get localDataTitle;

  /// No description provided for @back.
  ///
  /// In zh, this message translates to:
  /// **'返回'**
  String get back;

  /// No description provided for @localDataHeading.
  ///
  /// In zh, this message translates to:
  /// **'数据留在你手中'**
  String get localDataHeading;

  /// No description provided for @localDataBody.
  ///
  /// In zh, this message translates to:
  /// **'外观设置、加密 Telegram 会话与片库保存在本机，来源按账号隔离。默认服务的设备访问凭据单独保存在系统安全存储。退出登录会注销会话，关闭应用会保留登录。卸载和清理数据的行为依赖平台，开发目录需单独管理。'**
  String get localDataBody;

  /// No description provided for @mediaRightsHeading.
  ///
  /// In zh, this message translates to:
  /// **'使用你有权使用的媒体'**
  String get mediaRightsHeading;

  /// No description provided for @mediaRightsBody.
  ///
  /// In zh, this message translates to:
  /// **'能访问频道或群，不代表拥有其中影片的使用权。请遵守内容授权与来源规则；TG Cine 不提供影片内容。'**
  String get mediaRightsBody;

  /// No description provided for @unofficialNotice.
  ///
  /// In zh, this message translates to:
  /// **'TG Cine 是独立开源项目，与 Telegram 官方无隶属关系。'**
  String get unofficialNotice;

  /// No description provided for @selectedVideo.
  ///
  /// In zh, this message translates to:
  /// **'所选 Telegram 视频'**
  String get selectedVideo;

  /// No description provided for @openSelectedVideo.
  ///
  /// In zh, this message translates to:
  /// **'播放所选视频'**
  String get openSelectedVideo;

  /// No description provided for @developmentSelectedNotice.
  ///
  /// In zh, this message translates to:
  /// **'本机开发媒体入口：播放终端中已选择的视频。'**
  String get developmentSelectedNotice;

  /// No description provided for @developmentPlaybackNotice.
  ///
  /// In zh, this message translates to:
  /// **'开发播放器仍读取本机工具提供的私有媒体源，与应用内来源选择独立；长片定位仍可能缓冲。'**
  String get developmentPlaybackNotice;

  /// No description provided for @playbackLoading.
  ///
  /// In zh, this message translates to:
  /// **'正在准备视频…'**
  String get playbackLoading;

  /// No description provided for @playbackBuffering.
  ///
  /// In zh, this message translates to:
  /// **'正在缓冲，播放将在数据就绪后继续…'**
  String get playbackBuffering;

  /// No description provided for @playbackError.
  ///
  /// In zh, this message translates to:
  /// **'视频暂时无法播放。请确认本机媒体服务仍在运行，再重试。'**
  String get playbackError;

  /// No description provided for @playbackPlaying.
  ///
  /// In zh, this message translates to:
  /// **'正在播放'**
  String get playbackPlaying;

  /// No description provided for @playbackPaused.
  ///
  /// In zh, this message translates to:
  /// **'已暂停'**
  String get playbackPaused;

  /// No description provided for @playbackCompleted.
  ///
  /// In zh, this message translates to:
  /// **'播放结束'**
  String get playbackCompleted;

  /// No description provided for @playbackProgress.
  ///
  /// In zh, this message translates to:
  /// **'播放进度'**
  String get playbackProgress;

  /// No description provided for @playbackPause.
  ///
  /// In zh, this message translates to:
  /// **'暂停'**
  String get playbackPause;

  /// No description provided for @playbackPlay.
  ///
  /// In zh, this message translates to:
  /// **'播放'**
  String get playbackPlay;

  /// No description provided for @playbackReplay.
  ///
  /// In zh, this message translates to:
  /// **'重新播放'**
  String get playbackReplay;

  /// No description provided for @playbackBackward.
  ///
  /// In zh, this message translates to:
  /// **'后退 10 秒'**
  String get playbackBackward;

  /// No description provided for @playbackForward.
  ///
  /// In zh, this message translates to:
  /// **'前进 10 秒'**
  String get playbackForward;

  /// No description provided for @telegramConnectTitle.
  ///
  /// In zh, this message translates to:
  /// **'连接你的 Telegram'**
  String get telegramConnectTitle;

  /// No description provided for @telegramConnectBody.
  ///
  /// In zh, this message translates to:
  /// **'使用你自己的账号，选择已有权限的媒体来源。登录后可在本机保存来源选择。'**
  String get telegramConnectBody;

  /// No description provided for @telegramConnect.
  ///
  /// In zh, this message translates to:
  /// **'连接 Telegram'**
  String get telegramConnect;

  /// No description provided for @telegramConnecting.
  ///
  /// In zh, this message translates to:
  /// **'正在连接…'**
  String get telegramConnecting;

  /// No description provided for @telegramContinue.
  ///
  /// In zh, this message translates to:
  /// **'继续'**
  String get telegramContinue;

  /// No description provided for @telegramPhone.
  ///
  /// In zh, this message translates to:
  /// **'国际格式手机号'**
  String get telegramPhone;

  /// No description provided for @telegramPhoneHint.
  ///
  /// In zh, this message translates to:
  /// **'+ 国家码和手机号'**
  String get telegramPhoneHint;

  /// No description provided for @telegramCode.
  ///
  /// In zh, this message translates to:
  /// **'Telegram 验证码'**
  String get telegramCode;

  /// No description provided for @telegramPassword.
  ///
  /// In zh, this message translates to:
  /// **'两步验证密码'**
  String get telegramPassword;

  /// No description provided for @telegramEmail.
  ///
  /// In zh, this message translates to:
  /// **'登录邮箱'**
  String get telegramEmail;

  /// No description provided for @telegramEmailCode.
  ///
  /// In zh, this message translates to:
  /// **'邮箱验证码'**
  String get telegramEmailCode;

  /// No description provided for @telegramLoginPrivacy.
  ///
  /// In zh, this message translates to:
  /// **'验证码和密码仅用于本次验证，不保存在 TG Cine 设置中。Telegram 会话加密保存在本机。'**
  String get telegramLoginPrivacy;

  /// No description provided for @telegramInvalidInput.
  ///
  /// In zh, this message translates to:
  /// **'输入格式不正确，请检查后重试。'**
  String get telegramInvalidInput;

  /// No description provided for @telegramAuthenticationError.
  ///
  /// In zh, this message translates to:
  /// **'验证未通过，请检查验证码或密码后重试。'**
  String get telegramAuthenticationError;

  /// No description provided for @telegramStorageError.
  ///
  /// In zh, this message translates to:
  /// **'本机来源记录未能保存或读取，原记录已保留。请重试。'**
  String get telegramStorageError;

  /// No description provided for @telegramConnectionError.
  ///
  /// In zh, this message translates to:
  /// **'连接或加载失败，请检查网络后重试。'**
  String get telegramConnectionError;

  /// No description provided for @telegramUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'当前平台的 Telegram 接入尚未就绪。'**
  String get telegramUnavailable;

  /// No description provided for @telegramUnsupportedAuth.
  ///
  /// In zh, this message translates to:
  /// **'当前登录步骤暂不支持。请使用已有 Telegram 客户端完成账号注册后重试。'**
  String get telegramUnsupportedAuth;

  /// No description provided for @telegramCancelLogin.
  ///
  /// In zh, this message translates to:
  /// **'取消本次登录'**
  String get telegramCancelLogin;

  /// No description provided for @telegramChooseSources.
  ///
  /// In zh, this message translates to:
  /// **'选择媒体来源'**
  String get telegramChooseSources;

  /// No description provided for @telegramSourcesBody.
  ///
  /// In zh, this message translates to:
  /// **'从主列表和归档中选择来源。'**
  String get telegramSourcesBody;

  /// No description provided for @telegramSearchSources.
  ///
  /// In zh, this message translates to:
  /// **'搜索已加载的来源'**
  String get telegramSearchSources;

  /// No description provided for @telegramNoSources.
  ///
  /// In zh, this message translates to:
  /// **'没有匹配的来源；可调整搜索或加载更多。'**
  String get telegramNoSources;

  /// No description provided for @telegramLoadingSources.
  ///
  /// In zh, this message translates to:
  /// **'正在加载来源…'**
  String get telegramLoadingSources;

  /// No description provided for @telegramLoadMore.
  ///
  /// In zh, this message translates to:
  /// **'加载更多来源'**
  String get telegramLoadMore;

  /// No description provided for @telegramSourcesSelected.
  ///
  /// In zh, this message translates to:
  /// **'已选择 {count} 个来源'**
  String telegramSourcesSelected(int count);

  /// No description provided for @telegramSaveSources.
  ///
  /// In zh, this message translates to:
  /// **'保存选择'**
  String get telegramSaveSources;

  /// No description provided for @telegramSourcesSaved.
  ///
  /// In zh, this message translates to:
  /// **'来源选择已保存在本机'**
  String get telegramSourcesSaved;

  /// No description provided for @telegramLogout.
  ///
  /// In zh, this message translates to:
  /// **'退出登录'**
  String get telegramLogout;

  /// No description provided for @telegramConfirmLogout.
  ///
  /// In zh, this message translates to:
  /// **'确认退出登录'**
  String get telegramConfirmLogout;

  /// No description provided for @telegramKeepLogin.
  ///
  /// In zh, this message translates to:
  /// **'保持登录'**
  String get telegramKeepLogin;

  /// No description provided for @telegramConnected.
  ///
  /// In zh, this message translates to:
  /// **'已连接'**
  String get telegramConnected;

  /// No description provided for @telegramDevelopmentConnection.
  ///
  /// In zh, this message translates to:
  /// **'本机开发接入：会话由应用持有；公共默认服务尚未开放。'**
  String get telegramDevelopmentConnection;

  /// No description provided for @telegramSourcesNote.
  ///
  /// In zh, this message translates to:
  /// **'不按聊天类型过滤。只选择你有权使用的媒体来源；保存后可在片库开始分批导入。'**
  String get telegramSourcesNote;

  /// No description provided for @librarySearch.
  ///
  /// In zh, this message translates to:
  /// **'搜索已导入的文件、说明或来源'**
  String get librarySearch;

  /// No description provided for @libraryManageSources.
  ///
  /// In zh, this message translates to:
  /// **'管理来源'**
  String get libraryManageSources;

  /// No description provided for @libraryImportSources.
  ///
  /// In zh, this message translates to:
  /// **'导入来源'**
  String get libraryImportSources;

  /// No description provided for @libraryImportNotice.
  ///
  /// In zh, this message translates to:
  /// **'分批整理消息，不下载视频。应用切到后台时暂停；再次打开后可继续。'**
  String get libraryImportNotice;

  /// No description provided for @libraryImportCount.
  ///
  /// In zh, this message translates to:
  /// **'已导入 {count} 个视频'**
  String libraryImportCount(int count);

  /// No description provided for @libraryImportStart.
  ///
  /// In zh, this message translates to:
  /// **'开始导入'**
  String get libraryImportStart;

  /// No description provided for @libraryImportContinue.
  ///
  /// In zh, this message translates to:
  /// **'继续导入'**
  String get libraryImportContinue;

  /// No description provided for @libraryImportPause.
  ///
  /// In zh, this message translates to:
  /// **'暂停导入'**
  String get libraryImportPause;

  /// No description provided for @libraryImportRunning.
  ///
  /// In zh, this message translates to:
  /// **'正在整理历史消息…'**
  String get libraryImportRunning;

  /// No description provided for @libraryImportPaused.
  ///
  /// In zh, this message translates to:
  /// **'已暂停'**
  String get libraryImportPaused;

  /// No description provided for @libraryImportComplete.
  ///
  /// In zh, this message translates to:
  /// **'历史整理完成'**
  String get libraryImportComplete;

  /// No description provided for @libraryImportIdle.
  ///
  /// In zh, this message translates to:
  /// **'等待导入'**
  String get libraryImportIdle;

  /// No description provided for @libraryImportError.
  ///
  /// In zh, this message translates to:
  /// **'导入或读取未完成，已保存的内容仍保留。请重试。'**
  String get libraryImportError;

  /// No description provided for @libraryStorageError.
  ///
  /// In zh, this message translates to:
  /// **'本机媒体记录暂时无法读取或保存，请重试。'**
  String get libraryStorageError;

  /// No description provided for @libraryNoMedia.
  ///
  /// In zh, this message translates to:
  /// **'尚无已导入的视频'**
  String get libraryNoMedia;

  /// No description provided for @libraryNoMediaBody.
  ///
  /// In zh, this message translates to:
  /// **'从来源开始导入；首批视频保存后会出现在这里。'**
  String get libraryNoMediaBody;

  /// No description provided for @libraryNoResults.
  ///
  /// In zh, this message translates to:
  /// **'没有匹配的已导入视频'**
  String get libraryNoResults;

  /// No description provided for @libraryClearSearch.
  ///
  /// In zh, this message translates to:
  /// **'清除搜索'**
  String get libraryClearSearch;

  /// No description provided for @libraryLoadMore.
  ///
  /// In zh, this message translates to:
  /// **'加载更多视频'**
  String get libraryLoadMore;

  /// No description provided for @libraryRetry.
  ///
  /// In zh, this message translates to:
  /// **'重新读取'**
  String get libraryRetry;

  /// No description provided for @libraryFileDetails.
  ///
  /// In zh, this message translates to:
  /// **'文件详情'**
  String get libraryFileDetails;

  /// No description provided for @librarySelectFile.
  ///
  /// In zh, this message translates to:
  /// **'选择一个视频查看文件信息'**
  String get librarySelectFile;

  /// No description provided for @libraryUnknownFile.
  ///
  /// In zh, this message translates to:
  /// **'未命名视频'**
  String get libraryUnknownFile;

  /// No description provided for @libraryUnknownSource.
  ///
  /// In zh, this message translates to:
  /// **'来源名称未加载'**
  String get libraryUnknownSource;

  /// No description provided for @libraryUnknownDuration.
  ///
  /// In zh, this message translates to:
  /// **'时长未知'**
  String get libraryUnknownDuration;

  /// No description provided for @libraryFileSize.
  ///
  /// In zh, this message translates to:
  /// **'文件大小'**
  String get libraryFileSize;

  /// No description provided for @libraryDuration.
  ///
  /// In zh, this message translates to:
  /// **'时长'**
  String get libraryDuration;

  /// No description provided for @librarySource.
  ///
  /// In zh, this message translates to:
  /// **'来源'**
  String get librarySource;

  /// No description provided for @libraryOriginalCaption.
  ///
  /// In zh, this message translates to:
  /// **'原消息说明'**
  String get libraryOriginalCaption;

  /// No description provided for @libraryCopySource.
  ///
  /// In zh, this message translates to:
  /// **'复制源消息链接'**
  String get libraryCopySource;

  /// No description provided for @librarySourceCopied.
  ///
  /// In zh, this message translates to:
  /// **'链接已复制，可在 Telegram 中查看'**
  String get librarySourceCopied;

  /// No description provided for @librarySourceLinkError.
  ///
  /// In zh, this message translates to:
  /// **'暂时无法取得源消息链接，请检查来源权限后重试。'**
  String get librarySourceLinkError;

  /// No description provided for @libraryDetailsUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'当前条目已不可用，请返回片库。'**
  String get libraryDetailsUnavailable;

  /// No description provided for @libraryLoading.
  ///
  /// In zh, this message translates to:
  /// **'正在读取本机片库…'**
  String get libraryLoading;

  /// No description provided for @telegramDefaultConnection.
  ///
  /// In zh, this message translates to:
  /// **'默认服务自动连接。Telegram 登录会话与片库保存在本机，无需填写服务地址或访问令牌。'**
  String get telegramDefaultConnection;

  /// No description provided for @telegramServiceLimited.
  ///
  /// In zh, this message translates to:
  /// **'默认服务额度或连接数已达上限，请暂停导入并稍后重试。'**
  String get telegramServiceLimited;

  /// No description provided for @serviceConnected.
  ///
  /// In zh, this message translates to:
  /// **'已连接'**
  String get serviceConnected;

  /// No description provided for @serviceConnecting.
  ///
  /// In zh, this message translates to:
  /// **'连接中'**
  String get serviceConnecting;

  /// No description provided for @telegramServiceAccessExpired.
  ///
  /// In zh, this message translates to:
  /// **'默认服务访问已失效，请重新连接以重新启用。'**
  String get telegramServiceAccessExpired;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
