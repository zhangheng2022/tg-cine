# Domain

业务模型放在 `models/`，Repository / Service 抽象放在 `ports/`，需要编排的业务流程放在 `use_cases/`。
保持纯 Dart，只依赖本层与 Dart 标准库；不依赖 Flutter、ForUI、Data 或 UI。

当前没有已实现的业务，不创建占位模型、端口或用例。Telegram、媒体和观看进度接入时按需添加。
