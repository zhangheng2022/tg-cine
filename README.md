# TG Cine

Telegram 支持的开源个人电影与电视剧播放器。手机与宽屏同时适配，使用 Flutter / Dart 和 [ForUI](https://forui.dev/docs)，不使用 Go。

不限制平台，已生成 Android、iOS、Web、Windows、macOS、Linux 六个平台模板。
界面包含片库、观看记录、设置三个页面，ForUI 触控主题、系统明暗模式和中文界面。
基础架构参照 `meet_trace` 的分层 MVVM，详见 [基础架构](docs/architecture.md)。
独立的 TypeScript Worker 工程使用官方 `create-cloudflare` 模板，详见 [Worker 基础架构](docs/worker-architecture.md)。
Worker 提供健康检查和中转入口的鉴权、协议与目标校验，真实中转仍不可用，未部署。
Telegram 登录、媒体读取、播放器、TDLib 原生库及 Flutter 中转客户端尚未接入。

## 开发

验证环境：Flutter 3.47.7 / Dart 3.13.5。ForUI 0.27.4 要求 Flutter 3.47.0 及以上。
工程模板由以下官方命令生成（已有 Dart 文件保留）：

```powershell
flutter create --platforms=android,ios,web,windows,macos,linux --project-name=tg_cine --org=io.tgcine --empty app
```

用 `flutter doctor -v` 检查目标平台工具链；Android 需要 Android SDK，Windows 需要 Visual Studio C++ 工具链，iOS / macOS 构建需要 macOS 和 Xcode。

```powershell
cd app
flutter pub get
flutter run
```

Worker 使用 Node.js 24 和 npm，在独立目录开发：

```powershell
cd worker
npm ci
Copy-Item .dev.vars.example .dev.vars
npm run dev
```

`.dev.vars` 仅供本地使用，已忽略；填写独立的 `RELAY_TOKEN`，`RELAY_TARGETS` 目标白名单默认为 `{}`。
`dev` 强制使用本地 Wrangler，不需要 Cloudflare 凭据。接口与配置契约见 [Worker 基础架构](docs/worker-architecture.md)。

## 检查与构建

在 `app` 目录执行：

```powershell
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build apk --debug
flutter build web
flutter build windows --debug
```

调试 APK 位于 `app/build/app/outputs/flutter-apk/app-debug.apk`，用于开发验证，正式发布前需配置签名。

已在本机通过格式检查、静态分析、7 项组件 / ViewModel / 架构测试，以及 Android 调试 APK、Web 和 Windows 调试构建。
初始化版本曾在 Pixel 10 模拟器验证页面导航、系统明暗主题、1.3 倍字体和 48dp 主按钮；本次分层重构通过组件测试验证对应行为。
真机、iOS / macOS / Linux 构建和远程 GitHub Actions 尚未验证。

Worker 在 `worker/` 内执行：

```powershell
npm run format:check
npm run check
npm test
npm run build
```

`check` 生成已忽略的 Wrangler 类型文件，再运行源码和测试的 TypeScript 静态检查；测试使用 Vitest Workers 运行时。
`build` 只执行 `wrangler deploy --dry-run`，产物写入 `worker/dist/`，不会部署；工程不提供部署脚本。

本次初始化在 Windows / Node.js 24 下通过 `npm ci`、格式检查、源码与测试类型检查、34 项 Workers 运行时测试和 dry-run 构建。
本地 Wrangler 的 `/health` 返回 `200` 且 `tunnel: false`；未配置凭据的中转请求返回 `503`。本地验证服务已停止，远程 CI 尚未运行。

## 目录

- `app/lib/main.dart`：启动入口。
- `app/lib/app/`：应用外壳、流程组装及 ViewModel 生命周期。
- `app/lib/ui/features/`：片库、记录、设置与主导航；View / ViewModel 分离。
- `app/lib/ui/core/`：共享 ForUI 空状态组件。
- `app/lib/domain/`、`app/lib/data/`：业务层和实现层约定，尚无占位业务代码。
- `app/lib/theme/`：统一 ForUI 主题。
- `app/lib/l10n/`：ARB 中文文案及生成代码。
- `app/test/`：页面导航、小屏、大字体、明暗主题、ViewModel 与分层检查。
- `worker/src/`：请求入口、鉴权、协议、目标白名单及明确不可用的中转入口。
- `worker/test/`：Workers 运行时的健康检查与入口校验测试。
- `.github/workflows/ci.yml`：独立的 Flutter 和 Worker 检查任务，无 Cloudflare 凭据或部署步骤。

后续按中转连通、Telegram 登录、分片播放的顺序接入；Telegram 会话及其相关密钥只保存在设备上，中转凭据单独配置。
