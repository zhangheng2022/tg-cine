# 应用内 Telegram 登录与来源选择

本文记录登录、来源选择、保存与恢复。后续历史元数据导入已接入片库，见 [历史导入](library-import.md)；不修改播放器下载调度或部署 Worker。iOS 与 Android 共用 Domain、Repository、ViewModel 和 ForUI 页面；平台差异集中在原生库与会话保护。

## 调用与生命周期

`Application → SourcesViewModel → TelegramRepository → TdlibTelegramRepository → TDLib / RelayBridge / 本机存储`。

App 创建和释放账号依赖。一个接收泵通过 `@extra` 分发 RPC；原开发工具通过导出文件复用同一实现。登录支持手机号、验证码、两步验证、邮箱与邮箱验证码；未知步骤明确提示不支持。手机号提交前校验；提交、步骤切换和页面释放时清空敏感输入，不将验证码或密码写入本机记录。

恢复授权后先执行 `getMe`，再读取该账号的来源选择。主列表和归档分页合并，按聊天 ID 去重，不按类型过滤；搜索只过滤已经加载的条目，加载更多不清空选择；切换导航后同步恢复搜索输入与过滤条件。保存仅提交来源选择；用户随后在片库手动开始历史元数据导入，不自动下载媒体。普通关闭保留登录，退出登录需要页面二次确认并调用 TDLib `logOut`；取消未完成的登录只关闭客户端，不发送登出请求。

`logOut` 返回后仍需等原生 `authorizationStateClosed`，再撤销中转凭据和释放连接。遇到未完成的退出时，重新连接保持中转并等待最多 45 秒，随后最多重建一次客户端；反复关闭或超时显示连接错误。2026-10-14 Windows 缺失固定目标与状态回退问题已修复，真实运行恢复手机号页且用户确认可见；细节见 [公共接入记录](public-service.md)。

Windows 使用 DPAPI、目录 ACL 与排他锁；移动端使用同一 `MobileSession`，随机密钥通过 [flutter_secure_storage](https://pub.dev/packages/flutter_secure_storage) 保存。来源选择已迁入独立加密 SQLite，按账号隔离，旧 DPAPI/安全存储记录保留并按账号迁移一次；媒体密钥与 TDLib 密钥分开。iOS 使用本机 Keychain 可访问级别，Android 禁用自动备份，iOS 会话及媒体目录排除备份。数据库存在但密钥缺失时失败并保留原数据，不生成替代密钥。见 [本机媒体数据](local-media-data.md)。

## Windows 开发入口

在仓库根目录运行：

```powershell
powershell -File tool/run_telegram_app.ps1 -ApiEnvFile <本机API配置路径>
```

Windows 启动脚本默认连接公共服务，自动取得独立凭据，不读取开发中转令牌；默认使用独立 `app-account` 会话。需要复用既有开发授权时添加 `-UseExistingSession`；同一会话不能同时在外部工具和 App 中打开。不要在聊天中发送手机号、验证码、密码或配置内容。直接运行 `flutter run` 未注入应用标识或本机配置时，只提供未配置界面；静态设计稿不执行 Telegram 授权。

## iOS 与 Android 同步打包

两端固定使用 TDLib 提交 `c15d3f5a5de6e3ba5839822c451152e5e18bb700`。`.github/workflows/tdlib-mobile.yml` 的双端源码构建与带库验收已通过，见 [阶段验收](library-acceptance.md)；`build_mobile_tdlib.sh` 使用该提交的官方 Android/iOS 构建脚本。Android 生成 arm64-v8a、x86_64 JSON 库；iOS 生成设备与模拟器框架，再组成 XCFramework。框架构建必须在 macOS/Xcode 上进行，本轮由云端完成。

构建包包含来源提交和文件 SHA-256 清单。安装前检查：

```text
python tool/install_mobile_tdlib.py <构建包目录> --check
python tool/install_mobile_tdlib.py <构建包目录>
```

Android 放入已忽略的 `android/app/src/main/jniLibs/`；iOS 放入已忽略的 `ios/TDLib/Frameworks/tdjson.xcframework`，由本地 CocoaPod 嵌入。携带项目 API 标识的 Debug/Profile/Release 构建均检查必需原生库，缺失直接失败；没有库的 UI 模板构建不计为 Telegram 接入通过。Android 已完成真实授权和片库验收；iOS 模拟器原生库、隔离存储/导入通过，带框架无签名设备包构建成功，真实 iPhone 仍需签名安装环境。详见 [移动原生记录](mobile-native.md)。

在仓库根目录 准备本机 Debug 配置：

```text
dart run tool/prepare_mobile_config.dart <API配置> <relay-bridge.json> <令牌文件>
flutter run --debug -d <设备ID> --dart-define-from-file=.cache/deployment/flutter-mobile-defines.json
```

该配置包含开发凭据，只用于本机 Debug，不可分发。Android/iOS 的公开构建入口拒绝非空开发配置。默认服务现已支持自动配置、独立设备凭据、刷新/撤销与请求限流；公开构建只注入项目 Telegram 应用标识并打包 TDLib，不携带共享开发令牌。Windows Debug 可额外指定 `TG_CINE_USE_DEFAULT_SERVICE=true`，保留本机会话路径并改用公共凭据；构建和验收边界见 [默认服务](public-service.md)。

## 验证边界（历史记录）

以下是此前轮次的结果；当前 238 项 Flutter、双端原生 CI 及真实 Android 片库结果以 [阶段验收](library-acceptance.md) 为准，不将模拟器协议替身计为真实 iOS 授权。

- Flutter 146 项单元/组件测试通过，覆盖 Android/iOS 平台变体、手机/中屏/宽屏、明暗、两倍字体、登录步骤、来源选择、重启恢复与失败重试。
- Windows Data 真实会话两次重开、`getMe` 和主列表/归档读取通过；Windows Flutter 内真实会话恢复与来源列表显示也通过；未打印账号、来源名称或消息标识，未读取媒体。
- Windows 原生 Flutter 设计数据流程与 32 张截图通过。截图中的 Android/iOS 名称是 Flutter 平台变体，不是对应 OS 的真机截图。
- Android Debug APK 已携带 arm64-v8a、x86_64 TDLib。2026-10-15 NE2210 正常应用经官方动态目标策略完成手机号、验证码、两步验证至 ready，界面无错误；会话保留。此前隔离数据来源/恢复测试通过，真实移动来源保存及重开仍待验收。iOS 共用逻辑同步更新，原生库、构建、签名及真机未验证。详见 [动态策略](telegram-network-policy.md)。
- Android 公开构建使用虚构开发配置进行反向检查，已被 Debug 专用保护拦截；Web 与 Windows Debug 正常构建通过。
- 构建包安装器、公开配置检查器及固定源码归档校验的 Python 自测通过；Android 原生构建脚本已在 WSL Ubuntu 实际执行，远程原生构建矩阵未运行。

本地 Code Review 能力仅提供 PR CI 查询，因此本轮依据源码与差异完成手动审查；修复异步释放顺序和导航切换后的搜索状态不同步，并复跑相关回归。未发布 PR 评论或触发远程 CI。

本轮停止播放排查，已有播放限制仍保留在 `playback-stability.md`，不以账号或 UI 测试代替播放稳定性结论。
