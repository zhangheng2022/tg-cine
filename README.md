# TG Cine

Telegram 支持的开源个人电影与电视剧播放器。手机端优先，使用 Flutter / Dart 和 [ForUI](https://forui.dev/docs)，不使用 Go。

不限制平台，已生成 Android、iOS、Web、Windows、macOS、Linux 六个平台模板。
界面包含片库、观看记录、设置三个页面，ForUI 触控主题、系统明暗模式和中文界面。
基础架构参照 `meet_trace` 的分层 MVVM，详见 [基础架构](docs/architecture.md)。
Telegram 登录、媒体读取、播放器、TDLib 原生库和 Cloudflare Worker 尚未接入。

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

## 目录

- `app/lib/main.dart`：启动入口。
- `app/lib/app/`：应用外壳、流程组装及 ViewModel 生命周期。
- `app/lib/ui/features/`：片库、记录、设置与主导航；View / ViewModel 分离。
- `app/lib/ui/core/`：共享 ForUI 空状态组件。
- `app/lib/domain/`、`app/lib/data/`：业务层和实现层约定，尚无占位业务代码。
- `app/lib/theme/`：统一 ForUI 主题。
- `app/lib/l10n/`：ARB 中文文案及生成代码。
- `app/test/`：页面导航、小屏、大字体、明暗主题、ViewModel 与分层检查。
- `.github/workflows/ci.yml`：格式、静态分析、组件测试、Web 与 Android 调试构建。

后续按中转连通、Telegram 登录、分片播放的顺序接入；会话和密钥只保存在设备上。
