# 客户端架构

Flutter 工程直接位于仓库根目录，采用 View → ViewModel → Use Case / Port → Repository / Service。`lib/app/` 为组合根，负责依赖创建、注入和释放；UI 不直接访问 Data，Domain 保持纯 Dart。

`lib/ui/features/` 按片库、观看记录、来源、设置和播放器组织。ForUI、中文 ARB、可用宽度布局、字体缩放及 48dp 主操作控件保持原约定。

`lib/data/services/telegram/` 实现 TDLib 生命周期和授权状态；Android/iOS/Windows 接入默认服务。`lib/data/services/relay/` 是客户端运行组件，负责配置、设备凭据、动态目标策略和仅监听环回的 SOCKS5 → WSS 桥接。它已接入原生登录，不能移到服务端仓库。

本机媒体使用加密 SQLite，密钥由平台保护；来源、片库、导入检查点和观看状态不上传中转服务。目录整理不改变应用 ID、系统数据目录或开发会话的原绝对位置。

Worker 独立于 [tg-cine-worker](https://github.com/zhangheng2022/tg-cine-worker)。客户端只依赖 [v2 网络契约](https://github.com/zhangheng2022/tg-cine-worker/blob/main/docs/protocol.md)，构建无需 Node 或服务端源码。双方真实回环由服务端联调脚本接受显式客户端目录执行。

播放器已有 Windows Debug 工具媒体源与控制界面，完整播放和片库到播放/续看的接线仍需独立验收，见 [播放说明](flutter-player.md)。六平台模板不代表六平台业务可用。

检查从根目录执行 `flutter analyze`、`flutter test` 与相关构建；`test/architecture/` 保留层依赖约束。
