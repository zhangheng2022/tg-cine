# Domain

业务模型放在 `models/`，Repository / Service 抽象放在 `ports/`，需要编排的业务流程放在 `use_cases/`。
保持纯 Dart，只依赖本层与 Dart 标准库；不依赖 Flutter、ForUI、Data 或 UI。

当前包含外观设置模型与 SettingsRepository 端口，已经由真实存储和 UI 使用。Telegram、媒体和观看进度接入时按需添加，不创建占位模型、端口或用例。
