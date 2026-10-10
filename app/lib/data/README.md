# Data

领域端口的实现放在 `repositories/` 和 `services/`，存储 / 接口 DTO 与映射放在 `models/`。
平台插件、网络与持久化在本层接入；不反向依赖 App 或 UI。

当前没有真实数据源，不创建伪 Repository、通用 HTTP 包装或空依赖容器。
实际接入时由 `lib/app/` 组装实现，并通过 Domain 端口 / 用例注入 ViewModel。
