# 仓库贡献指南

## 项目结构与模块组织

技术栈为 Flutter/Dart 与 TypeScript Worker，UI 使用 ForUI，不使用 Go。

- `app/` 为 Flutter 客户端，保留 Android、iOS、Web、Windows、macOS、Linux 六个平台模板，界面须同时适配手机与宽屏。
- `app/lib/ui/features/` 按功能组织 View 和 ViewModel；`app/lib/ui/core/` 存放共享 ForUI 组件。`app/lib/app/` 负责依赖创建与释放；Domain 保持纯 Dart，Data 实现服务和仓库，UI 不直接访问 Data。
- 主题和中文 ARB 文案分别位于 `app/lib/theme/`、`app/lib/l10n/`；平台图标和资源位于 `app/<platform>/`。
- `worker/src/` 包含 TypeScript 路由、鉴权、协议、目标校验和中转骨架。测试位于 `app/test/`、`worker/test/`，架构说明位于 `docs/`。

## 构建、测试与本地开发

工具版本以 CI 和工程配置为准，当前使用 Flutter 3.47.7 和 Node.js 24；在对应工程目录执行命令。

- 在 `app/`：`flutter pub get` 安装依赖，`flutter run` 启动客户端。
- `dart format lib test tool`、`flutter analyze`、`flutter test` 分别执行格式化、静态分析和测试。
- `flutter build web`、`flutter build apk --debug` 验证 CI 使用的构建目标。
- 在 `worker/`：`npm ci` 安装锁定依赖，`npm run dev` 启动本地 Wrangler。
- `npm run format:check`、`npm run check`、`npm test` 分别检查格式、生成并检查类型、运行测试。
- `npm run build` 仅执行 Wrangler dry-run 打包，不部署。

## 代码风格与命名

遵循 Dart 格式化工具和 `flutter_lints`：使用两空格缩进，文件采用 `snake_case.dart`，类型采用 `UpperCamelCase`，成员采用 `lowerCamelCase`。Worker 使用 Prettier，配置为制表符缩进、单引号、分号及 140 字符行宽。

优先使用 ForUI、`context.theme` 和 `context.l10n`，保留安全区域、字体缩放和 48dp 主操作控件。修改 ARB 后运行 `flutter gen-l10n`，不手动编辑生成文件。

根据可用窗口宽度组织响应式布局，手机与宽屏同步设计、实现和验证，不仅依据设备类型或系统平台判断布局。

## 测试要求

Flutter 使用 `flutter_test`，测试目录镜像源码路径，文件命名为 `*_test.dart`。界面变更须覆盖手机、宽屏及字体缩放场景。Worker 使用 Vitest 和 `@cloudflare/vitest-plugin`，文件命名为 `*.spec.ts`。测试应覆盖变更行为、失败路径和鉴权边界；当前未配置覆盖率百分比门槛。创建 PR 前运行相关检查。

## 技能与审查工作流

按任务使用 `grill-me`、`impeccable`、`open-codereview` 和 `graphify`；技能先读取当前环境提供的 `SKILL.md`，工具遵循实际接口。用户要求“先给方案”时只分析，执行范围以用户授权为准。

### grill-me：方案质询与决策澄清

- 用户明确调用 `/grill-me` 或要求深入质询方案、设计时启用，不自动用于普通开发。入口位于 `.agents/skills/grill-me/SKILL.md`，委托 `grilling` 执行；先读取两者说明。
- 源码、配置和调用关系先自行查证，只向用户询问需要其决定的问题。将决策组织为依赖树，每轮集中询问前提已确定的问题，编号并给出建议；等待回答后再推进依赖这些答案的问题。
- 结合任务核对手机与宽屏适配、ForUI 组件与 Flutter 分层、Worker 协议及鉴权白名单。整理已确认决策和待定事项，用户确认理解一致后再按授权实施；质询本身不授权部署。

### Impeccable：界面设计与验收

- Flutter 界面新增、调整和 UX 审查使用 `impeccable`。先按技能的 context 流程读取 `PRODUCT.md`、`DESIGN.md` 与 `.impeccable/surfaces/` 中的对应页面约定；实际编辑 UI 前读取技能的 `reference/craft-floor.md`。
- 保留 ForUI、中文文案和既有交互；按可用窗口宽度同时设计手机与宽屏。用 Flutter 渲染、组件测试和截图验证，不能将 HTML/CSS 检测器作为 Flutter UI 验收依据。
- 集中检查手机、宽屏、明暗主题与字体缩放，批量修复后最多再确认一轮；记录未实测的平台。

### open-codereview：变更审查

- 功能、安全或架构变更完成相关检查后，使用 `open-codereview` 或当前环境的 Code Review 能力审查本次差异。明确本地 diff 范围或 PR 当前 HEAD，保留用户已有改动。
- 重点检查 Flutter 分层、响应式与交互，以及 Worker 校验顺序、凭据、白名单和失败路径。问题须给出文件行号、触发条件与影响；修复后复跑相关检查。
- 工具不可用时说明限制并基于 `git diff` 与源码完成审查。打开审查面板不等于完成审查；发布 PR 评论、批准或合并须另有用户授权。

### Graphify：架构与调用关系

- 架构、依赖和调用链分析优先查询现有 `graphify-out/graph.json`，先按图谱词汇扩展查询。示例：`graphify query "authorize tunnel target" --budget 1500`；追踪关系可用 `graphify path` 或 `graphify explain`。
- 核对图谱与当前源码是否一致，引用来源位置，区分 `EXTRACTED`、`INFERRED` 和 `AMBIGUOUS`。技能文档节点不代表项目已实现功能；聚合度与连接数不能单独决定架构拆分。
- 明确请求初建或更新时使用 `/graphify .`、`/graphify . --update`；普通查询不触发全量重建。输出保持在已忽略的 `graphify-out/`，hooks 和 watch 仅在用户明确要求时启用。

## 提交与拉取请求

提交标题使用简短、明确的中文，例如 `初始化 Worker 基础架构与持续集成`，每次提交聚焦一个主题。PR 应说明行为变化、关联相关问题、列出验证结果和未测试的平台；界面变更附手机与宽屏截图。

## 安全与配置

凭据保存在已忽略的 `.dev.vars` 或 Worker Secrets 中，与 Telegram 会话分开。保留 `RELAY_TARGETS` 默认空白名单，不提交密钥或构建产物。中转默认关闭并返回 `501`；实验性启用和本地回环不代表 Telegram 或边缘中转通过，不能将开发共享令牌写入公开客户端。部署须获得明确授权。
