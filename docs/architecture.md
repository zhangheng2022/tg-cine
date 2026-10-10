# 基础架构

参考本机 `meet_trace` 的分层 MVVM，保留 `app/` 作为 Flutter 工程根目录。
使用 `flutter create --platforms=android,ios,web,windows,macos,linux --project-name=tg_cine --org=io.tgcine --empty app` 生成官方模板。
不限制平台，手机端界面优先；当前工程模板已覆盖六个平台，具体业务的跨平台支持在接入时验证。
`worker/` 为独立的 TypeScript Cloudflare Worker 工程，见 [Worker 基础架构](worker-architecture.md)；本次初始化不新增 Flutter 中转客户端或业务依赖。

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

当前 `Application` 只组装主题、本地化和 `TgCineFlow`；Flow 创建并释放 `HomeViewModel`，HomeView 监听导航状态。
片库、观看记录、设置分别独立为 View，共享空状态放在 `ui/core/`。尚无业务依赖，不建立空容器或空 Use Case。
页面尚无加载流程，因此暂不引入参考项目的 ViewLoading / ViewData / ViewError；真实异步数据接入时按实际状态添加。

主题沿用 ForUI neutral touch，默认跟随系统；中文文案迁入 `app_zh.arb`，界面行为保持一致。
增加文案后运行 `flutter gen-l10n`，生成文件由工具维护。当前只提供中文，不增加语言切换。

`app/test/` 镜像对应源码目录，另由 `test/architecture/` 检查分层依赖。
在 `app/` 内执行 `dart format lib test`、`flutter analyze`、`flutter test`、`flutter build apk --debug`。

只沿用参考项目的组织方式；录音、ASR、Sentry、自动更新和三端发布流程未迁入。
