# 移动 TDLib 交付记录

更新：2026-10-15。Android 已完成原生交付、默认服务真实授权及真实片库关卡；iOS 同提交源码构建、模拟器原生/隔离流程及带框架无签名设备构建通过。真机与签名仍待验收，最新证据见 [阶段验收](library-acceptance.md)。

## 来源与产物

使用 TDLib 1.8.68，固定提交 `c15d3f5a5de6e3ba5839822c451152e5e18bb700`，在 WSL Ubuntu 执行官方 Android 构建脚本。NDK r28c (`28.2.13676358`) 下载校验与 [官方历史下载记录](https://github.com/android/ndk/wiki/Unsupported-Downloads) 一致；OpenSSL 3.6.5 与 C++ 运行库静态链接，最低原生 API 23。

Git 获取超时时，可通过 `TGCINE_TDLIB_ARCHIVE` 使用固定源码 ZIP，SHA-256 为 `a11844b92c4da66119dd50e2d434ec987c1e04ee991a8ed74d6dd4b50360e667`；脚本先校验再提取。`TGCINE_OPENSSL_ARCHIVE` 可使用脚本固定 SHA-512 的本机归档。路径逃逸或摘要不符直接失败，不使用任意版本源码。

| ABI | 字节数 | SHA-256 |
| --- | ---: | --- |
| arm64-v8a | 18861128 | `7d41ff60c37532c5852775f9adb97c91bdc3e598e88b5dd71e6ebe8a69494551` |
| x86_64 | 21974112 | `e620afc03cb5732a9eaecc52b342e1334d035cc48651ad3eacb9118d3b598f88` |

两库均为对应架构 ELF64，四个现代 JSON C 导出完整，LOAD 对齐 16384 字节，仅依赖 Android 系统库。APK 内摘要与安装清单一致，`zipalign -c -P 16 4` 通过；这些静态检查不替代 16 KiB 系统的运行验收。

## 构建与验证

Linux/macOS 在仓库根目录构建，安装及 Flutter 命令在仓库根目录 执行：

```text
bash tool/build_mobile_tdlib.sh android
python tool/install_mobile_tdlib.py .cache/native/mobile-build/android/package --check
python tool/install_mobile_tdlib.py .cache/native/mobile-build/android/package
flutter build apk --debug --dart-define-from-file=.cache/deployment/flutter-public-defines.json
flutter test integration_test/tdlib_native_test.dart -d <设备ID>
flutter test integration_test/default_telegram_test.dart -d <设备ID> --dart-define-from-file=.cache/deployment/flutter-public-defines.json
```

iOS 将构建参数替换为 `ios`，必须使用 macOS/Xcode；对应框架由 CocoaPods 嵌入。携带项目 API 标识时，Android 检查两 ABI 库并限制相应架构，iOS 检查 XCFramework；Debug/Profile/Release 均拒绝缺库。开发私有配置仍仅允许 Debug。产物、配置与会话保持忽略，不提交仓库。

iOS 构建显式指定 `IOS_DEPLOYMENT_TARGET=15.0`。安装器同时检查设备 arm64、模拟器 arm64/x86_64 的 Mach-O 平台与实际最低版本，拒绝只声明 iOS 15、实际需要新系统的框架；不修改二进制标记。旧的最低版本 26.5 产物已停用，新产物三个架构均为 15.0，四个现代 JSON C 导出完整。本轮未单独在 iOS 15 系统运行，最低版本兼容仍需实测。

## 最新真实授权

2026-10-15 正常入口 APK 已升级为 [官方动态目标策略](telegram-network-policy.md)，NE2210 经默认服务依次进入验证码、两步验证及 `authorizationStateReady`；界面无错误、无目标拒绝。用户仅在应用内输入验证信息，诊断只读脱敏枚举和流量计数。登录会话已保留，未清除数据或退出账号。全量 Flutter 234 项、Worker 64 项通过；最终 11 项中转回归、APK 构建、两 ABI 摘要和 16 KiB zipalign 检查通过。

以下预登录及旧 APK 摘要为历史记录；真实来源保存、重开和导入的最新结果以阶段验收为准。

## 实测边界（历史）

- x86_64 Android 模拟器、arm64 NE2210 真机：实际库加载、初始授权状态及正常关闭通过。
- 模拟器：默认服务与实际 Application 手机号表单通过。真机另检查启用的 `127.0.0.1` 代理及真实原生 `pingProxy`，随后检查实际手机号表单；未输入或提交任何账号验证信息。
- 全量 230 项 Flutter 测试与分析通过；Python 构建配置及源码归档自测在 WSL 全部通过，Windows 跳过 Linux/macOS 脚本执行项。58 项 Worker 测试、类型、格式与 dry-run 通过。

集成测试结束会卸载测试包，必须重新构建、安装正常入口，不能把测试 APK 交付用户。本轮已重新构建并安装正常应用；流式安装失败后改用 `adb install --no-streaming -r` 成功，实际 MainActivity 启动及 VM 只读状态复核为 `phone`、`defaultService=true`、`relayReady=true`，账号和 ViewModel 均无错误。正常 APK SHA-256 为 `3d5badfe99381d3971ec28e011704afe40b69b45f98b7c3bc495afd14de713d3`。

上述历史记录中的待办已有更新：Android 真实来源/片库及远程原生 CI 已完成；iPhone 真机与 16 KiB 系统运行仍待验收。本轮不继续播放排查；默认接入额度及部署记录见 [默认服务](public-service.md)。
