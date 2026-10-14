# 基础架构

## Windows 开发播放器增量

`domain/ports/playback.dart` 定义纯 Dart 状态与控制端口；Data 的 `MediaKitPlayback` 实现插件调用，UI 的 `PlayerViewModel` 管理命令、失败与离页暂停。App 组合根创建播放器、视频输出和 ViewModel，并在销毁时释放；UI 通过注入的画面组件显示视频，不直接访问 Data。

真实媒体暂由外部本机 TDLib 工具提供。Windows Debug 按显式配置读取受保护的短期回环清单，Release、Web 与其他平台不启用此源；未将令牌或 Telegram 会话移入公开客户端。播放器关闭磁盘缓存，区分包缓存与字节缓冲，预读限定 10 秒、HTTP 超时为 30 秒；有音轨时为同一文件创建独立音频输入。私有 HTTP 的视频与音频别名各自替换旧响应，最多两个活动响应和两个等待请求；TDLib 读取保持串行，仅取消被替换响应正在持有的读取，并预留字节预算。启动新的 2 MiB 下载窗后先等待整窗可读，避免另一条轨道在预取尚未完成时替换它；取消和失败清理保留。

前一分钟此前已验证；本轮只解码模式的中点及回退有通过记录，片尾持续播放仍失败。合成视频绕开纹理输出后正常前进，具体窗口/渲染原因待前台验证；这不消除真实源的数据供应问题，见 [播放器接入](flutter-player.md)。

参考本机 `meet_trace` 的分层 MVVM，保留 `app/` 作为 Flutter 工程根目录。
使用 `flutter create --platforms=android,ios,web,windows,macos,linux --project-name=tg_cine --org=io.tgcine --empty app` 生成官方模板。
不限制平台，手机与宽屏界面须同时适配；当前工程模板已覆盖六个平台，具体业务的跨平台支持在接入时验证。布局依据可用窗口宽度响应变化，界面变更须同时验证手机与宽屏场景。
`worker/` 为独立的 TypeScript Cloudflare Worker 工程，见 [Worker 基础架构](worker-architecture.md)。原生可行性工具与 Flutter UI 分开运行，业务接入状态见 [开发执行记录](development-plan.md)。

```text
app/lib/
  main.dart                 启动入口
  app/                      应用外壳、流程组装及依赖生命周期
  ui/
    core/                   共享 ForUI 组件
    features/<feature>/
      views/                页面与交互绑定
      view_models/          ChangeNotifier 状态与操作
  domain/                   纯 Dart 模型、端口与用例
  data/                     端口实现、平台服务与 DTO
  theme/                    统一 ForUI 主题
  l10n/                     ARB 文案、生成代码和 context.l10n
```

调用方向为 `View → ViewModel → Use Case / Port → Repository / Service`。
App 是组合根，负责创建具体实现、注入依赖并释放资源；UI 不直接访问 Data、平台插件、存储或 HTTP。
Domain 不依赖 Flutter 或上层实现；Data 只依赖 Domain 和自身实现。

`Application` 组装真实本机设置仓库与 SettingsViewModel，负责加载、释放以及系统/浅色/深色主题。`TgCineFlow` 创建并释放 HomeViewModel；HomeView 监听四项导航，设置页通过纯 Dart SettingsRepository 端口读写外观。
片库、观看记录、来源、设置分别独立为 View，本机数据说明为内容路由；共享空状态放在 ui/core/。不建立空容器或空 Use Case。
设置页的异步读取、保存和重试由 SettingsViewModel 的明确状态管理；其他页面目前只有空状态，不引入空的 ViewLoading / ViewData / ViewError 通用容器。

主题沿用 ForUI neutral touch，默认跟随系统，也可在本机保存浅色/深色选择；中文文案使用 app_zh.arb。
增加文案后运行 `flutter gen-l10n`，生成文件由工具维护。当前只提供中文，不增加语言切换。

`app/test/` 镜像对应源码目录，另由 `test/architecture/` 检查分层依赖。
在 `app/` 内执行 `dart format lib test tool`、`flutter analyze`、`flutter test`、`flutter build apk --debug`。

只沿用参考项目的组织方式；录音、ASR、Sentry、自动更新和三端发布流程未迁入。

原生可行性桥接在 Data Service 中使用 dart:io，由 tool/relay_bridge.dart 运行，未从 UI 导入，也不进入当前 Web 业务。实验协议见 worker-architecture.md，阶段记录见 development-plan.md。
