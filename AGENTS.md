# 客户端贡献指南

## 工程与分层

本仓库只维护 Flutter/Dart 客户端，UI 使用 ForUI，不使用 Go。Flutter 工程位于仓库根目录，保留 Android、iOS、Web、Windows、macOS、Linux 六平台。Worker 位于独立的 tg-cine-worker 仓库。

`lib/ui/features/` 按功能组织 View/ViewModel，`lib/ui/core/` 是共享组件。`lib/app/` 创建、注入和释放依赖；Domain 保持纯 Dart，Data 实现服务和仓库，UI 不直接访问 Data。中转客户端与 TDLib 留在 `lib/data/`。

## 开发检查

使用工程和 CI 锁定版本（Flutter 3.47.7）。在根目录运行 `flutter pub get`、`dart format --output=none --set-exit-if-changed lib test tool integration_test`、`flutter analyze`、`flutter test`、`python -m unittest discover -s tool -p 'test_*.py'`。格式修复时再运行 `dart format lib test tool integration_test`。相关构建包括 `flutter build web`、`flutter build apk --debug` 和平台构建。不要将可构建模板等同于真实平台业务验收。

采用两空格、snake_case 文件名、UpperCamelCase 类型。优先 ForUI、context.theme、context.l10n，保留安全区、字体缩放和 48dp 主操作。修改 ARB 后运行 flutter gen-l10n。界面按可用窗口宽度同时适配手机与宽屏，测试覆盖明暗主题与大字体。

## 技能与审查

- 用户明确调用 grill-me 时读取 `.agents/skills/grill-me/SKILL.md`，其委托的 grilling 为开发者环境技能；先查证事实，再按依赖顺序提问。用户要求先给方案时只分析。
- UI 新增、调整和 UX 审查使用环境提供的 impeccable，先读取 PRODUCT.md、DESIGN.md 和对应 `.impeccable/surfaces/`，编辑前读取 craft-floor。以 Flutter 渲染、组件测试和截图验收，不以 HTML 检测代替。
- 功能、安全、架构变更完成检查后使用 open-codereview 或可用 Code Review；工具不能审查 diff 时说明限制并人工审查。问题给行号、条件与影响；修复后复跑相关检查。PR 评论、批准和合并需要相应授权。
- 架构查询优先已有 Graphify 图并核对源码，区分 EXTRACTED/INFERRED/AMBIGUOUS；技能文档不代表实现。仅明确要求初建或更新时重建，产物忽略在 graphify-out/；watch/hooks 不自动启用。

## 数据与协议

客户端只使用 Worker v2，不维护旧接口兼容。切换时清理旧中转凭据，保留 Telegram 会话、来源、媒体数据库与观看记录。`.cache/native/accounts/` 是现有开发数据位置，改工具路径时不得写到父目录或误创建新账号库。

凭据、真实配置、构建产物、原生库不提交。公共客户端不包含共享开发中转令牌；Telegram 应用标识与账号会话不同。目标仅允许服务端提供的有效 Telegram 官方公网 CIDR 与固定 443，策略过期或失败时拒绝连接。部署须另行明确授权。

## 提交

中文简短标题，一次提交聚焦一个主题。PR 描述行为、验证和未测平台；UI 改动附手机与宽屏证据。保留用户已有修改。
