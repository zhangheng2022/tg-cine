# TG Cine

Telegram 支持的开源个人电影与电视剧播放器。手机与宽屏同时适配，使用 Flutter / Dart 和 [ForUI](https://forui.dev/docs)，不使用 Go。

不限制平台，已生成 Android、iOS、Web、Windows、macOS、Linux 六个平台模板。
界面包含片库、观看记录、来源、设置四项导航，手机底栏、中屏图标侧栏、宽屏文字侧栏同步适配；ForUI 触控主题、中文界面和可持久化的本机外观设置。
基础架构参照 `meet_trace` 的分层 MVVM，详见 [基础架构](docs/architecture.md)。
独立的 TypeScript Worker 工程使用官方 `create-cloudflare` 模板，详见 [Worker 基础架构](docs/worker-architecture.md)。
Worker 提供健康检查、鉴权、Telegram 官方动态网段校验，以及默认关闭的受限 WebSocket/TCP 中转。线上经授权启用，取消固定 IP 列表，按需自动刷新官方范围；Android 真机已完成真实授权。契约与边界见 [动态目标策略](docs/telegram-network-policy.md) 和 [部署记录](docs/worker-deployment.md)。
Windows Debug 已接入真实 Flutter 播放器与 ForUI 控制页，可通过本机工具提供的私有媒体源播放所选 Telegram 视频；手机与宽屏布局同时验证。应用内登录、频道选择、TDLib 打包和续看尚未接入，启动与验证边界见 [Flutter 播放器](docs/flutter-player.md)。
TDLib Windows x64 库已从官方固定提交构建，独立 Dart ABI/生命周期验证通过；尚未作为 Flutter 资源打包。来源、复现与验证命令见 [原生构建记录](docs/native-tdlib.md)。
完整阶段、当前交付及验收边界见 [开发执行记录](docs/development-plan.md)。

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

`.dev.vars` 仅供本地使用，已忽略；私有开发模式填写独立的 `RELAY_TOKEN`；服务端无固定目标配置，启用后只允许 Telegram 官方动态网段内的公网 IP:443。
`dev` 强制使用本地 Wrangler，不需要 Cloudflare 凭据；`RELAY_ENABLED` 默认 `false`。接口、实验限制及配置契约见 [Worker 架构](docs/worker-architecture.md)。

## 检查与构建

在 `app` 目录执行：

```powershell
dart format --output=none --set-exit-if-changed lib test tool integration_test
flutter analyze
flutter test
flutter build apk --debug
flutter build web
flutter build windows
```

调试 APK 位于 `app/build/app/outputs/flutter-apk/app-debug.apk`，用于开发验证，正式发布前需配置签名。

已在本机通过格式检查、静态分析、97 项测试；新增播放器通过 Windows Debug/Release 和 Web 构建，既有 UI 基础此前通过 Android 调试 APK。测试覆盖 320/800/1440 窗口、明暗及字体缩放、外观与存储失败、播放命令和错误恢复、桥接、本机密钥、聊天选择、可读范围、私有 HTTP Range 的同流替换、跨流隔离、关闭和分层。其他平台的构建与真实播放须重新验收。
Android 模拟器已检查四项导航、本机说明、手机/中屏/宽屏和 1.3 倍字号。Android 真机原生加载、默认服务登录及隔离数据流程已有验证；iOS / macOS / Linux 构建与远程 GitHub Actions 尚未验证；CI 已配置六平台构建目标。

Worker 在 `worker/` 内执行：

```powershell
npm run format:check
npm run check
npm test
npm run build
npm run test:relay
```

`check` 生成已忽略的 Wrangler 类型文件，再运行源码和测试的 TypeScript 静态检查；测试使用 Vitest Workers 运行时。
`build` 只执行 `wrangler deploy --dry-run`，产物写入 `worker/dist/`，不会部署；工程不提供部署脚本。

本次增量在 Windows / Node.js 24 下通过格式检查、类型检查、43 项 Workers 运行时测试和 dry-run 构建。`test:relay` 需 Flutter 依赖已安装，验证实际本地 workerd/TCP 的 1 MiB 双向有序传输与退出，不证明 Telegram 播放或边缘环境可用。
仓库默认配置下 `/health` 的 `tunnel` 为 `false`；未配置凭据返回 `503`，校验通过但关闭中转时返回 `501`。线上实验配置已启用，见部署记录；远程 CI 尚未运行。

## 目录

- `app/lib/main.dart`：启动入口。
- `app/lib/app/`：应用外壳、流程组装及 ViewModel 生命周期。
- `app/lib/ui/features/`：片库、记录、来源、设置、本机说明与主导航；View / ViewModel 分离。
- `app/lib/ui/core/`：共享 ForUI 空状态组件。
- `app/lib/domain/`：纯 Dart 外观模型和仓库端口；`app/lib/data/`：本机设置仓库与实验原生桥接。
- `app/tool/`：桥接、本地联调、TDLib ABI/线上连通性验证与 Windows 本机开发登录入口；使用方式见 `docs/native-tdlib.md`。
- `app/lib/theme/`：统一 ForUI 主题。
- `app/lib/l10n/`：ARB 中文文案及生成代码。
- `app/test/`：页面导航、小屏、大字体、明暗主题、ViewModel 与分层检查。
- `worker/src/`：请求入口、鉴权、协议、官方动态网段策略和默认关闭的实验传输。
- `worker/test/`：Workers 运行时的入口校验、流控与失败清理测试。
- `.github/workflows/ci.yml`：独立的 Flutter 和 Worker 检查任务，无 Cloudflare 凭据或部署步骤。

Windows TDLib 经应用内桥接和线上 Worker 的五个 DC 密钥握手、初始化、真实账号授权和 `getMe` 已通过；本机来源选择、消息和文件信息读取已验证。21 MB 与 1.26 GB 样本通过范围读取、复读及 VLC 两段视频解码。2026-10-13 已部署有界下行窗口：同一大样本两个 512 KiB 冷读取由 48.7 / 56.3 秒降至 2.59 / 1.39 秒；开发工具加入连续预取、MP4 索引准备和旧读取取消，首段首张 PNG 由约五分四十秒降至两轮约 14.7 / 7.3 秒。新增会话检查中，有缓冲的 60 秒音视频播放通过，但原大样本中点跳转后的持续播放失败，完整会话未通过。**Windows Debug 已接入 Flutter 播放器，首帧、暂停恢复、后退和前一分钟连续定位已验证**；冷定位等待、远距离定位、续看、实际听感与完整电影仍待验收，客户端入口与测试见 [Flutter 播放器](docs/flutter-player.md)，详见 [原生验证记录](docs/native-tdlib.md)。Telegram 会话及其相关密钥只保存在设备上，中转凭据单独配置。公开发行前必须替换共享开发令牌并验证配额、费用和审核要求。

2026-10-14 稳定性排查：前台与普通 Flutter 对照将本机冻结范围缩小到硬件解码路径；Windows 开发入口使用软件解码并保留 GPU 输出。单接收泵 RPC 分发、可读数据旁路后，原大样本中点通过严格 60 秒 GUI 检查，片尾仍有缓冲，完整电影未通过。链路统计已增加，线上 tail 连接超时，不能进一步确定边缘网络段。详见 [播放稳定性验证](docs/playback-stability.md)。
