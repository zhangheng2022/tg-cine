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
  /// **'当前版本在本机保存外观设置。Windows 开发联调会复用独立的本机 Telegram 会话和媒体缓存，播放器只读取私有本机媒体源；应用内登录和片库导入尚未接入。卸载应用或清理浏览器站点数据会移除外观设置，开发会话与缓存需单独清理。'**
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
  /// **'Windows 开发联调：播放本机终端已选择的授权媒体。应用内登录与来源选择尚未接入，长片定位仍可能缓冲。'**
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
