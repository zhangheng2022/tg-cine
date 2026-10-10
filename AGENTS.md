# TG Cine 协作约定

- 沟通和文档使用中文；Flutter 工程位于 `app/`，TypeScript Worker 工程位于 `worker/`。
- 不限制平台，保留 Android、iOS、Web、Windows、macOS、Linux 官方模板；手机端界面优先，UI 使用 ForUI，不使用 Go。
- 当前范围为 Flutter 基础架构和 Worker 初始化；不扩大到 Telegram、播放或真实中转，不部署。
- 架构参照 [基础架构](docs/architecture.md)：View → ViewModel → Use Case / Port → Repository / Service。
- UI 在 `app/lib/ui/features/`，共享组件在 `ui/core/`；Domain 保持纯 Dart，UI 不直接访问 Data，Data 不反向依赖 App / UI。
- `app/lib/app/` 是组合根，负责依赖创建、注入与释放；按实际功能添加依赖，不创建占位容器。
- 优先使用 ForUI、`context.theme` 与 `context.l10n`，保持安全区域、字体缩放和 48dp 主操作按钮。
- `app/test/` 镜像源码；Dart 改动运行格式、静态分析和受影响测试，依赖或平台改动增加本机可执行的对应构建。
- Worker 架构参照 [Worker 基础架构](docs/worker-architecture.md)；变更运行 `npm run format:check`、`npm run check`、`npm test` 和 `npm run build`，构建只使用 Wrangler dry-run。
- Worker 默认空目标白名单；鉴权凭据与 Telegram 会话分开，未实现的中转能力必须明确返回不可用，不允许任意目标转发。
- 不提交凭据、密钥或构建产物；未实际验证的登录、播放、连通性不得写成完成。
- 修改源码后运行 `graphify update .`，图文件保持忽略。
