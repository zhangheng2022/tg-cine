# TG Cine

个人 Telegram 电影与电视剧客户端，使用 Flutter / Dart 和 ForUI，中文界面同时适配手机与宽屏。

本仓库只维护客户端。Flutter 工程位于仓库根目录；服务端独立维护于 [tg-cine-worker](https://github.com/zhangheng2022/tg-cine-worker)，采用 Cloudflare Workers + Vite，API 使用 TypeScript / Hono。两端仅使用 v2 协议，不兼容旧客户端；服务端上线前，新版默认连接不可用。

## 开发与检查

使用 Flutter 3.47.7、Dart 3.13.5，在仓库根目录执行：

```powershell
flutter pub get
flutter run
dart format --output=none --set-exit-if-changed lib test tool integration_test
flutter analyze
flutter test
python -m unittest discover -s tool -p 'test_*.py'
flutter build web
flutter build apk --debug
flutter build windows
```

保留 Android、iOS、Web、Windows、macOS、Linux 六个平台工程。构建模板通过不代表 Telegram 业务和播放均可用。当前原生接入实现面向 Android、iOS、Windows；iOS/macOS 构建需要 macOS/Xcode。

携带项目 Telegram 应用标识的原生构建必须先安装已核验的 TDLib。步骤见 [移动原生构建](docs/mobile-native.md)、[客户端接入](docs/telegram-app.md) 和 [默认服务](docs/public-service.md)。本机配置、会话、密钥、数据库及原生构建产物均不提交。

## 结构

- `lib/app/`：依赖组装与释放；`lib/domain/`：纯 Dart 模型和端口。
- `lib/data/`：平台服务、TDLib、加密本机存储与 v2 中转客户端。
- `lib/ui/`：ForUI View / ViewModel；`lib/theme/`、`lib/l10n/`：主题与中文文案。
- `tool/`：本机开发和原生库构建/校验；`test/`、`integration_test/`：测试。
- `docs/`、`.impeccable/`：客户端架构、设计、历史验收；`.agents/skills/`：Dart/Flutter 和通用技能。

当前业务状态见 [阶段验收](docs/library-acceptance.md)，拆仓状态见 [迁移说明](docs/repository-split.md)。Android 真实片库和 iOS 模拟器已有历史验收；完整电影播放、iPhone 签名真机及 Web Telegram 业务仍有未完成事项。
