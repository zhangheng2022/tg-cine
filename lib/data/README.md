# Data

领域端口由 `repositories/` 和 `services/` 实现；存储 DTO 与映射位于 `models/`。平台插件、HTTP、TDLib 和持久化在本层接入，不反向依赖 UI 或 App。

`services/relay/` 实现 v2 配置、独立设备凭据与本机 SOCKS5/WSS 桥接，已被原生 Telegram 登录使用。服务端实现位于独立的 tg-cine-worker 仓库。

普通外观设置使用 shared_preferences；会话、密钥和媒体数据库使用平台保护及加密存储。`lib/app/` 负责组装具体实现并通过 Domain 端口注入 ViewModel。
