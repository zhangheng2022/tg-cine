# TG Cine 协作约定

- 沟通和文档使用中文；Flutter 工程位于 `app/`。
- 不限制平台，保留 Android、iOS、Web、Windows、macOS、Linux 官方模板；手机端界面优先，UI 使用 ForUI，不使用 Go。
- 当前不扩大到 Telegram、播放或中转实现。
- 架构参照 [基础架构](docs/architecture.md)：View → ViewModel → Use Case / Port → Repository / Service。
- UI 在 `app/lib/ui/features/`，共享组件在 `ui/core/`；Domain 保持纯 Dart，UI 不直接访问 Data，Data 不反向依赖 App / UI。
- `app/lib/app/` 是组合根，负责依赖创建、注入与释放；按实际功能添加依赖，不创建占位容器。
- 优先使用 ForUI、`context.theme` 与 `context.l10n`，保持安全区域、字体缩放和 48dp 主操作按钮。
- `app/test/` 镜像源码；Dart 改动运行格式、静态分析和受影响测试，依赖或平台改动增加本机可执行的对应构建。
- 不提交凭据、密钥或构建产物；未实际验证的登录、播放、连通性不得写成完成。
- 修改源码后运行 `graphify update .`，图文件保持忽略。
