# TDLib 原生构建与验证

更新日期：2026-10-13。此记录覆盖本机 Windows x64 可行性构建；原生库未打包进 Flutter，其他原生平台及 Web 不由此结论推导。

## 来源与依赖

| 项目 | 固定版本 / 提交 | 用途与许可证 |
| --- | --- | --- |
| [TDLib](https://github.com/tdlib/td/tree/c15d3f5a5de6e3ba5839822c451152e5e18bb700) | 1.8.68 / `c15d3f5a5de6e3ba5839822c451152e5e18bb700` | 官方 JSON C 接口；BSL-1.0 |
| [vcpkg](https://github.com/microsoft/vcpkg/tree/e456309491fd875487bf02b8a0dca76c1b1b00cc) | `e456309491fd875487bf02b8a0dca76c1b1b00cc`；工具 2026-09-26 | 固定依赖端口；MIT |
| OpenSSL | 3.6.5#1 / `x64-windows-static` | 静态链接；Apache-2.0 |
| zlib | 1.3.2#2 / `x64-windows-static` | 静态链接；Zlib |
| gperf | 3.3#1 / `x64-windows` | 仅构建工具；不作为应用库分发 |

构建使用 Visual Studio 18 2026、MSVC 19.51.36252.0、Windows SDK 10.0.26100、CMake 4.3.1-msvc1。源代码通过官方 GitHub codeload 的固定提交归档取得，未修改 TDLib 的业务源码。下载、依赖、生成文件和产物均位于已忽略的 `.cache/native/`；不将第三方库或凭据提交仓库。

## 复现命令

在仓库根目录运行，先将上述固定提交的源码置于对应目录；CMake、Visual Studio C++ 工具链须已安装并可用。以下路径均为仓库内路径，不能将个人机器的工具安装路径写入构建配置。

```powershell
$nativeBuildRoot = (Resolve-Path .cache/native).Path
$tdSource = Join-Path $nativeBuildRoot 'sources/td-c15d3f5a5de6e3ba5839822c451152e5e18bb700'
$tdVcpkg = Join-Path $nativeBuildRoot 'sources/vcpkg-e456309491fd875487bf02b8a0dca76c1b1b00cc/vcpkg.exe'
$env:VCPKG_DOWNLOADS = Join-Path $nativeBuildRoot 'downloads'
$env:VCPKG_MAX_CONCURRENCY = '2'
& $tdVcpkg install openssl:x64-windows-static zlib:x64-windows-static gperf:x64-windows `
  --x-install-root="$nativeBuildRoot/installed" --disable-metrics
cmake -S $tdSource -B "$nativeBuildRoot/build-windows" -G 'Visual Studio 18 2026' -A x64 `
  -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTING=OFF -DCMAKE_POLICY_DEFAULT_CMP0091=NEW `
  -DCMAKE_MSVC_RUNTIME_LIBRARY=MultiThreaded -DOPENSSL_USE_STATIC_LIBS=TRUE `
  "-DCMAKE_PREFIX_PATH=$nativeBuildRoot/installed/x64-windows-static" `
  "-DZLIB_LIBRARY=$nativeBuildRoot/installed/x64-windows-static/lib/zs.lib" `
  "-DGPERF_EXECUTABLE=$nativeBuildRoot/installed/x64-windows/tools/gperf/gperf.exe"
cmake --build "$nativeBuildRoot/build-windows" --config Release --target tdjson --parallel 2
```

`BUILD_TESTING=OFF` 只跳过第三方 TDLib 自身的构建测试，不替代项目的 Dart、Worker 和 ABI 验证。Windows vcpkg 静态 zlib 的库名为 `zs.lib`，须显式提供，不能套用其他平台库名。

## Dart 验证

在仓库根目录 执行：

```powershell
dart run tool/verify_tdlib.dart .cache/native/build-windows/Release/tdjson.dll
```

工具仅接受本机库路径，通过共享 `tool/support/tdlib_probe.dart` 调用四个现代 JSON 接口；读取版本，检查 `authorizationStateWaitTdlibParameters`，再等待 `authorizationStateClosed`。响应在下一次 native 调用前复制，请求内存由 Dart 释放；接收使用 `td_receive(0)`，每批最多 32 个事件后异步让出，避免阻塞同一 isolate 中的桥接。单次请求以 `@extra` 关联、按 `@client_id` 过滤，状态等待有 5 秒上限；工具仅支持单客户端/单接收者。失败不打印原生响应或账号信息。接口约定见 [TDLib JSON 文档](https://core.telegram.org/tdlib/docs/td__json__client_8h.html)。

本验证不设置 API 凭据、不创建 Telegram 数据库、不发起账号登录。TDLib 当前版本的代理 API 使用嵌套 `proxy` 对象，后续接入必须以固定提交的 `td_api.tl` 为准，不能照搬旧版 `proxy_id` 的 `pingProxy` 示例。

## 当前结果与边界

Windows x64 Release 构建成功；Dart 工具已通过格式化、静态分析、库路径不存在时的失败退出检查，以及实际原生库的 JSON ABI、初始状态和正常关闭验证。命令退出码为 0，输出 `Verified TDLib 1.8.68: JSON ABI, initial state and clean close. No account login.`。

本机产物为 `.cache/native/build-windows/Release/tdjson.dll`，33,510,912 字节，SHA256 为 `B516C0EE7B72A21C404AAD6C2DBFAF24D2E952E840394B5172291C7F578ED3C3`。这是此次构建的记录，不是不同工具链构建必然一致的承诺。`dumpbin` 确认四个现代 JSON 接口导出，动态依赖仅有 `WS2_32.dll`、`CRYPT32.dll`、`Normaliz.dll`、`KERNEL32.dll`、`USER32.dll`、`ADVAPI32.dll`，未依赖独立 OpenSSL/zlib DLL。

完整本机来源与产物记录保存在已忽略的 `.cache/native/build-manifest.json`；第三方原生单元测试、Native Assets 打包和 Flutter 内加载尚未验证。

本机直连源码中的默认 DC2 `149.154.167.51:443` 在 5 秒内未建立 TCP 连接。后续经用户授权部署新 Worker，十个固定目标的边缘 TCP/MTProto 握手已通过，见 [部署记录](https://github.com/zhangheng2022/tg-cine-worker/blob/master/docs/history/worker-deployment.md)。Windows TDLib 经 Dart 桥接的原生验证也已通过，范围如下。

## 线上 TDLib 验证

在仓库根目录 使用本机开发令牌文件，秘密只读入内存：

```powershell
$env:TG_CINE_RELAY_TOKEN_FILE = (Resolve-Path .cache/deployment/relay-token.txt).Path
dart run tool/verify_tdlib_relay.dart .cache/native/build-windows/Release/tdjson.dll .cache/deployment/relay-bridge.json
```

工具在未提供初始化参数时调用当前固定版本的 [testProxy](https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1test_proxy.html)。源码 `ProxyChecker.cpp` 实际执行 SOCKS5、MTProto 与临时 AuthKeyHandshake；不创建账号数据库、不需要 API 凭据。五个 DC 经 `tg-cine.zhangheng.eu.org` 返回 `ok`：DC1 4438 ms、DC2 2321 ms、DC3 4299 ms、DC4 2266 ms、DC5 2752 ms，随后原生客户端和桥接正常关闭。此结果比 Node 的单包 resPQ 探测覆盖更多原生握手步骤，仍不等于账号授权、媒体下载或持续吞吐。

## Windows 本机登录入口

先执行默认登录前检查，API 配置保持在原目录，只读取 `TG_API_ID` / `TG_API_HASH`，不输出字段值：

```powershell
dart run tool/telegram_login.dart .cache/native/build-windows/Release/tdjson.dll .cache/deployment/relay-bridge.json C:/Users/96227/Desktop/TGvideo/.env
```

已通过 `networkTypeNone`→启用环回 SOCKS5→设置参数的初始化顺序、`getProxies` 启用状态、显式代理 `pingProxy`、等待手机号和正常关闭。TDLib 固定源码在 `init_options_and_network()` 中按队列处理网络类型及代理，然后初始化其他管理器；没有为了测试调用 `disableProxy` 或直接目标 ping。第二次运行也成功解密并复用同一数据库。

需要实际登录时，在本机 PowerShell 终端从仓库根目录执行；不是聊天命令，也不把秘密放入命令行：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tool/login_local.ps1 -ApiEnvFile C:/Users/96227/Desktop/TGvideo/.env
```

`Bypass` 只应用于该子进程，不修改系统执行策略。程序在显式 `--login` 或 `--select-media` 且存在本机终端时启用网络。登录支持手机号、Telegram 验证码、邮箱/邮箱验证码和两步验证密码；手机号允许空格分组并正常显示，验证码及密码隐藏字符，密码不裁剪空白。按回车后显示提交提示，请求超时明确反馈。Ctrl+C 恢复回显并关闭客户端。登录成功还须验证 `getMe`，只保存不含账号信息的结果状态；工具不注册新账号或发起购买。验证码和密码不要发送到聊天中。

开发会话位于已忽略的 `.cache/native/accounts/dev-account/`，与 TGvideo 会话分离。目录 ACL 限当前 Windows 用户/SYSTEM；随机 32 字节数据库密钥通过原生 DPAPI 加密到 `key.dpapi`，解密值不经过 shell、环境变量或输出。锁防止并发打开同一会话；损坏/缺失密钥会失败并保留旧数据库，不自动生成替代密钥。停止程序使用 TDLib `close`，保留本机会话；完整登出/清理还未接入。不要只复制数据库来迁移账号，DPAPI 密钥的异机恢复尚未验证。

2026-10-12 用户在本机完成授权；结果为 `ready`、`getMeVerified=true`，关闭后重新打开加密会话也成功调用 `getMe`。初始化、登录和频道选择的连接诊断发现四个额外 DC 地址，分别加入固定白名单；未放宽任意目标校验。失败报告只保存受控阶段、数字错误码或 IP 目标，不保存验证输入和原生错误正文。

从聊天选择验收样本：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tool/login_local.ps1 -ApiEnvFile C:/Users/96227/Desktop/TGvideo/.env -SelectMedia
```

入口要求已授权会话，分页列出主列表和归档中的聊天，不按频道、群或私聊类型过滤，再查询所选聊天的普通视频和视频文件。名称只显示在本机；输入序号选择，`m` 查询更多，`q` 取消。选择保存在私有会话目录的 `media-selection.json`，仅包含时间、聊天 ID、消息 ID，未下载视频，也没有导入片库。控制字符被过滤；自毁视频不能选为持久验收样本。

本机测试覆盖 DPAPI 重开、互斥、损坏/缺失密钥保留、配置字段校验、输入回显、密码保持、接收泵让出和选择分页；Windows CI 加入密钥测试，其他系统跳过此 Windows 专项。**这些是开发验证工具，不是 Flutter 登录与来源界面，也不是正式六平台会话存储方案。**

### 所选媒体的字节范围验证

2026-10-12 本机已保存用户选择，重开会话后成功取得对应消息与视频文件信息。原样本大小 1,259,802,293 字节；当时实际下载为 0 字节，60 秒可读范围等待超时。原选择保留为私有目录的 `media-selection-before-control.json`。并发拒绝和 Worker `IDLE_TIMEOUT` 计数均为 0；这不能证明网络或媒体端点无问题。缓存文件的逻辑大小不能代替 TDLib 的可读范围。

用户另选的对照样本为 21,236,045 字节、100 秒的 MP4。2026-10-12T13:01:42Z 头部、中段、尾部共 1,313,101 字节读取通过，耗时分别 49,500 / 54,246 / 31,582 ms；头部复读一致。该结果证明这个样本的真实下载和随机字节读取可用，不能将原样本失败直接归因于文件大小，也不证明持续播放速度满足要求。

2026-10-13 恢复原选择，保留短样本的选择与成功报告。第一次复测首段读取成功，中段等待 60 秒超时；开发工具将范围等待放宽到两分钟，512 KiB 读取上限不变。2026-10-13T01:07:24Z 第二次复测通过：头部、中段、尾部偏移分别为 0 / 629,669,888 / 1,259,339,776，共读出 1,511,093 字节，耗时 46,086 / 39,353 / 54,518 ms，头部复读一致；样本为 2,982 秒的 MP4。本次不再复现全程零字节，但各段实际耗时都低于原 60 秒限制，不能据此断言放宽等待是唯一原因，也不能宣称此前故障根因已定位。未修改或重新部署 Worker。

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tool/login_local.ps1 -ApiEnvFile C:/Users/96227/Desktop/TGvideo/.env -VerifyMedia
```

`--verify-media` 仅复用已授权会话，不发起登录。入口恢复所选来源并读取已选消息，按 512 KiB 上限检验头部、中部、尾部并复读头部。先检查 `getFileDownloadedPrefixSize`；缓存命中直接读取，缺少字节时复用或启动最多请求 2 MiB 的连续下载窗口。新窗口等待窗口末端可读再返回第一块，避免另一条轨道提前替换尚未完成的预取；已缓存和未切窗读取仍按请求量检查。相邻读取不逐次取消，切换到未缓存的新位置、失败或关闭时取消窗口；TDLib 分片对齐可能缓存额外字节。可读范围轮询的等待阈值为两分钟，再调用 `readFilePart`；原生 RPC 有独立超时，禁止读取空洞。未知大小、无效文件、自毁视频及外部 URL 文件生成均不进入读取。TDLib 的分片缓存位于私有会话目录，不导出完整视频；总缓存自动清理尚未实现。

成功结果写入 `media-probe.json`，失败保留 `probe-result.json`。诊断仅含受控阶段、字节计数、内部响应类型及固定目标 ID；不含聊天名称、消息正文、验证输入或凭据。字节验证与解码播放分别验收，不将范围读取等同于播放器通过。

### 本机解码验证入口

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tool/login_local.ps1 -ApiEnvFile C:/Users/96227/Desktop/TGvideo/.env -VerifyPlayback
```

入口复用已授权会话，恢复同一所选消息并校验文件信息；使用本机已安装的 VLC，从 0 秒和时长中点分别解码两秒，每次读取仍须等待 TDLib 可读范围。媒体只通过 `127.0.0.1` 的随机路径提供，校验 Host 和单个 HTTP Range；读取限制为 512 KiB、原生请求串行，允许一个等待请求。该端点只服务一个解码进程，新范围终止旧响应以解除写入阻塞；每段最多 32 MiB / 64 个请求，VLC 最多等待八分钟。失败时截断响应，不填充空洞；结束后停止后续读取，关闭端口和该次 VLC 子进程。无交互验证模式向 PowerShell 传递原生退出码，失败不能返回成功。

首段启动前预读最多 1 MiB 头部；MP4 按文件声明的顶层 box 长度扫描，最多检查 8 个头，支持 64 位扩展大小与到 EOF 的大小，跳过 `mdat` 后缓存最多 4 MiB 的 `moov`。异常长度、无法识别或超大索引回退到正常解码，不重写文件；预取仍通过有限下载窗口，不能视为总磁盘缓存上限。每 100 ms 检测首张 PNG，报告 `firstFrameDetectedMs`；首段计时含准备时间，第二段复用缓存，该数值不代表 Flutter 界面首次显示画面。

解码 PNG 只保存在私有会话目录的新子目录，原生日志不输出，成功报告 `playback-probe.json` 不包含媒体名称或播放 URL。这是 Windows 视频解码的开发检查，未验证音轨、用户拖动、连续播放或 Flutter 播放器。

2026-10-12T13:33:40Z 对照样本通过：VLC 从 0 秒和 50 秒分别正常退出，生成两张不同的 640×360 PNG；本机影像解析也通过。两段 HTTP 数据合计 3,145,728 字节，50 秒解码实际请求了偏移 10,306,142 字节的范围。读取中关闭和新范围替换阻塞响应均有回归测试；原生客户端及 VLC 验收进程已退出。这是两个短片段的视频解码证据，首播等待仍较长，原大样本失败原因未确定。

2026-10-13 原大样本第一次解码在四分钟时超时，已向 VLC 传送 2 MiB，但没有画面；失败报告保留，进程已退出。开发工具将单段解码等待延长到八分钟，32 MiB / 64 请求上限不变。2026-10-13T01:23:25Z 复测通过：0 秒与 1,491 秒（24 分 51 秒）分别解码两秒并正常退出，生成两张不同的 640×360 PNG，影像解析通过。两段 HTTP 合计 10,575,924 字节，中点实际请求偏移 639,278,656 字节；两段失败请求数均为 0。第二段复用同一 TDLib 会话的分片缓存，并非独立冷启动；按首段输出目录创建时间计，首张 PNG 创建约五分四十秒，末次 PNG 更新约六分二十二秒，不能据此判定播放流畅。原生客户端、VLC 和会话锁均已释放，原选择与短样本证据保留。本次通过未确定此前零字节失败的根因，音轨、手动拖动、连续播放和 Flutter 播放器仍未验收。

优化前的首段等待分析：只读取本机已缓存的 MP4 顶层 box 头，确认 `mdat` 从偏移 36 开始，`moov` 位于偏移 1,257,397,915，大小为 2,404,378 字节（约 2.29 MiB）。VLC 首段依次从头部、完整尾部索引、偏移 44 的视频数据读取，HTTP 合计 4,501,530 字节，含重复读取。当时的开发工具每次最多读 512 KiB，串行执行启动下载→等待可读前缀→读取→取消下载，没有连续预取；复测三个约 512 KiB 范围各耗时 39–55 秒。这些等待会累积为分钟级准备时间；下述诊断进一步定位传输瓶颈。

### 2026-10-13 下载分层定位

使用已忽略目录中的临时诊断副本，复用原大样本、已授权会话与实际默认服务，只记录数值计时和帧大小；未修改应用传输源码或部署 Worker。2026-10-13T02:01:21Z 完成，缓存重读逐字节一致，原选择、会话锁与子进程清理检查通过。

| 对照 | 结果 | 说明 |
| --- | --- | --- |
| Dart → 本地 workerd → TCP 回环，1 MiB | 136 ms，256 帧，每帧 4 KiB | 本机桥接与 Worker 回环本身可快速传输；逐字节校验通过 |
| 同域名健康请求 | 预热后 224–248 ms，首次 974 ms | 仅作为网络往返参考，不是媒体带宽测试 |
| 原视频冷读取 512 KiB，两次 | 48.7 s / 56.3 s | 各媒体连接约 151–152 帧，多数为 4 KiB |
| 冷读取期间本机媒体帧写入 | 累计 46 ms / 42 ms | 本机 Socket 写入远小于传输等待 |
| 同一客户端缓存重读 512 KiB | 78 ms | 数据已到本机后，读取与原生调用不是分钟级等待原因 |
| 一次连续下载 1 MiB，再分两次读取 | 合计 70.2 s | TDLib 使用两条媒体连接；第二次读取已命中缓存，不能当作独立下载测速 |
| 仅本地 ACK 增加 225 ms，512 KiB | 29.8 s，128 帧 × 4 KiB | 无真实 Telegram 上游也能复现明显降速；逐字节校验通过 |

优化前的主要瓶颈位于 **Worker 与客户端之间的逐帧确认协议**：`worker/src/relay.ts` 下行曾在每次 `server.send(frame)` 后执行 `await ack`，收到确认前不再读取下一段 TCP 数据。配置中的 64 KiB 是帧上限，实际媒体帧通常仅 4 KiB；冷样本媒体连接的相邻帧间隔中位数为 254 ms / 370 ms，而上传 ACK 中位数为 248 ms / 253 ms。每个小帧重复一次公网等待，约 150 次往返已经可以累积数十秒；原生解码、MP4 尾索引与串行读取进一步放大首播等待，但不能用它们解释传输层本身的限速。

诊断时核对线上 100% 流量版本 `4bd39257-ad3e-406e-94a7-be8bcbe8cc70` 与部署清单一致，六个 Worker 源文件的 SHA-256 均匹配。建议有界窗口流控，保留总字节、队列、目标白名单和失败关闭边界，再考虑连续预取；诊断阶段未实施，当时尚无边缘改造前后对照，不能据此承诺修复后的播放速度。

原始数值报告位于私有会话目录的 `download-profile.json`；汇总、回环与延迟对照结果位于已忽略的 `.cache/profiling/`。临时副本静态分析无问题，字节与统计自检通过；没有重新执行未改动的 Flutter UI、完整测试套件或平台构建。

### 2026-10-13 优化执行与复测

已部署有界下行窗口，线上版本为 `466e7289-959b-4437-bb97-7ce884690ed9`，兼容 v1 逐帧 ACK；安全边界见 [Worker 架构](https://github.com/zhangheng2022/tg-cine-worker/blob/master/docs/architecture.md)。保持客户端原先的读取逻辑，在 2026-10-13T02:28:55Z 完成同一视频的对照，首轮开始下载时 TDLib 的已下载字节为 0，桥接记录到实际媒体传输：

| 检查 | 优化前 | 仅 Worker 窗口优化后 |
| --- | --- | --- |
| 512 KiB 冷读取，头部 | 48.706 s | 2.591 s |
| 512 KiB 冷读取，相邻块 | 56.301 s | 1.388 s |
| 512 KiB 缓存重读 | 77.9 ms | 40.6 ms |
| 连续下载 1 MiB | 70.220 s | 2.707 s |

随后加入连续预取与索引准备。2026-10-13T02:37:16Z 头/中/尾共 1,511,093 字节与复读通过，三个范围耗时 3.189 / 5.222 / 2.099 秒；这轮改变了下载窗口，不能与上一表当作完全相同的测速条件。2026-10-13T02:38:50Z VLC 首段及 1,491 秒段均正常退出，生成两张不同的 640×360 PNG，影像解析通过，失败请求均为 0。首段 PNG 检测约 14.7 秒，Windows 文件创建时间对照约 14.67 秒，包含 9.954 秒头部及 2,404,378 字节索引准备；优化前首张 PNG 约 339.9 秒。第二段 PNG 检测约 3.2 秒，复用同一会话缓存；两段 HTTP 合计 14,770,228 字节，VLC 提前读取量随速度变化，不作为固定数据量的吞吐比较。

收尾补充旧读取的协作取消：新 Range 或端点关闭时只标记旧读取失效，由旧读取在下一次原生调用返回后取消下载；新请求随后串行执行，不并发消费 TDLib JSON，不将正常替换计作播放失败。2026-10-13T02:49:47Z 最终范围复测与复读仍通过，耗时 2.817 / 6.027 / 3.615 秒；2026-10-13T02:50:40Z 最终 VLC 两段正常退出、无失败请求，首张 PNG 检测为 7.306 秒（含准备 6.561 秒），中点为 4.308 秒并复用缓存，HTTP 合计 12,673,076 字节。两轮首播约 7–15 秒，反映样本、缓存路径与当次网络差异，不能将变化全部归因于单一后续修改。

48 项 Worker 与全量 63 项 Flutter 测试、格式、静态分析通过，实际配置打包与回环字节校验通过。首段/中点解码、缓存字节复读、原选择保持、进程退出与会话锁释放已核对；清理 RPC 不覆盖最终成功或失败状态。当前 Code Review 能力仅提供 PR CI 读取，本次按源码和本地差异人工审查。原报告、前后计时与部署清单快照保存在已忽略的 `.cache/relay-window/`。

后续需要验证 Native Assets 的目标平台打包、第三方声明、ABI/CPU 架构、会话隔离、媒体 DC、音轨、交互拖动和持续播放。本次没有执行 Flutter 播放器验收、真机或六平台原生验证，也不能据单样本承诺所有网络的速度。

### 播放会话验收入口

在仓库根目录 设置 `TG_CINE_RELAY_TOKEN_FILE` 指向已忽略的中转令牌文件后执行：

```powershell
dart run tool/telegram_login.dart .cache/native/build-windows/Release/tdjson.dll .cache/deployment/relay-bridge.json C:/Users/96227/Desktop/TGvideo/.env --verify-session
```

要求所选视频至少 180 秒。复用本机加密会话，由同一 VLC 进程先播放 60 秒、跳到中点播放 15 秒、再回到 30 秒处播放 15 秒。控制接口只绑定 `127.0.0.1`，使用每次随机密码；原生日志、控制密码、播放 URL 和影片信息不写入报告。VLC 使用 dummy 视频输出和静音的 Windows `mmdevice` 音频输出，禁用音量保存；报告区分解码、输出计数与用户实际听感，未执行听感验收。

HTTP 每次向媒体读取器请求 64 KiB，再按 16 KiB 写出；每累计 64 KiB 让出事件循环，及时响应 demux 的范围切换。读取器根据已经可读的前缀，单次原生读取最多 512 KiB，复用至多八块（最多 4 MiB）的内存缓存，返回副本防止调用方修改缓存；关闭时释放。TDLib 仍按 2 MiB 窗口预取，起点向下对齐至 512 KiB 边界，避免非对齐窗口尾部不足却仍等待旧窗口。既有两段视频工具保留 32 MiB / 64 请求限制，会话检查显式使用 128 MiB / 512 请求；这些是有限开发验收预算，不适合完整长片播放。HTTP 预算包含反复读取本机缓存的字节，与 Worker 单连接的 Telegram 网络流量预算分别计量。

VLC 会话检查保留 `--prefetch-buffer-size=16384`（KiB），使用较小的 `--prefetch-read-size=65536`（字节）与 `--network-caching=5000`（毫秒）。启动前额外准备最多 8 MiB 文件头，准备耗时单独记录；播放窗口计时不包括这段等待。VLC 3 源码的两项预读默认值均为 16 MiB；缓冲大小与读取批次需要分别考虑，过小的访问层缓存也会增加反复跳读。配置来源见 [VideoLAN prefetch 实现](https://github.com/videolan/vlc-3.0/blob/master/modules/stream_filter/prefetch.c)。这些参数只用于该验收入口，不修改用户安装的 VLC 配置。

每秒采样播放时钟、解码、画面呈现与音频播放计数。等待播放时钟实际推进后开始单窗口计时；通过要求时钟按实际耗时推进（容差 3 秒），时钟、画面呈现和音频播放各自最长未推进不超过 5 秒，丢帧和丢音频缓冲计数不增加。解码器提前解码后可以暂停计数，不能把它单独当作呈现冻结。跳转后须到达目标时间附近并继续输出；任何状态、范围或预算错误都会保留数值证据并返回非零退出码。结果保存在私有会话的 `playback-session-probe.json`，不会覆盖原先的两段 PNG 验证报告。程序跳转、短时间播放、手动拖动、实际听感与 Flutter 验收分别记录。

### 2026-10-13 会话检查结果与 Flutter 接入缺口

本节记录 VLC 会话阶段的历史状态。后续已接入 Windows Debug Flutter 播放器，修复低层字节缓冲与重叠 Range 后，首帧、暂停恢复、30 秒定位、后退和前一分钟连续跳转通过；完整电影及远距离定位仍未验收。当前状态、对照记录与启动命令见 [Flutter 播放器接入](flutter-player.md)。

最终配置复测返回非零退出码，完整会话 **未通过**。第一个窗口通过：准备 23.529 秒（包含头部与索引、8 MiB 预缓冲），等待播放时钟启动另耗时 2.135 秒；窗口从 1 秒播放至 61 秒，实际耗时 60.693 秒，呈现画面增加 1,815 帧、播放音频缓冲增加 2,601 次，丢失计数均未增加，HTTP 传送 34,910,234 字节。该结果仅是有缓冲的短时间播放证明，不能替代完整电影的持续吞吐验收。

1,491 秒跳转等待 39.101 秒后开始采样；15.434 秒窗口只推进 7 秒，出现超过 6 秒的输出停顿与 10 次丢帧，HTTP 传送 32,489,472 字节，因此停止后续回到 30 秒的检查。报告保留失败状态，`programmaticSeekVerified` 与完整会话连续播放标记仍为 `false`。

只检查本机已经完整缓存的 MP4 索引，视频与音频时间表、样本大小表和分块表的样本总数各自一致，不能将它归为损坏文件。按表定位，1,491 秒视频数据约在 639,927,762 字节，音频数据约在 385,929,558 字节，两者相距约 254 MB；实际跳转也出现两组远距离读取。当前单文件下载窗不断在两组范围之间切换，单纯调小写出块、增加局部缓存或对齐窗口没有解决中点播放。需要进一步设计按轨道的多范围预取、定位准备和缓冲恢复；尚未做排除所有网络因素的对照。

76 项 Flutter 测试、格式和静态分析通过。新增检查覆盖缓存上限和返回副本、窗口边界、快速缓存响应的中断、HTTP 预算、时钟/呈现/音频输出冻结及丢失计数；解码计数暂停但输出继续的情况不会被误判。Code Review 没有本地 diff 接口，按源码与调用关系人工审查。各轮失败报告、计时与只含数值的索引检查保存在已忽略的 `.cache/playback-session/`。

**上述 VLC 验证阶段尚未接入 Flutter 播放器。** 当时改动仅在开发工具及其测试，没有播放器页面、Native Assets 打包或续看存储；这些历史结果不能作为 Flutter 首播或用户拖动证据。

## 当前 Flutter 接入与远距离检查

Windows Debug 已通过 Domain 播放端口和 App 组合根接入 `media_kit` 与 ForUI 控制页；来源仍由外部本机 TDLib 工具持有，应用内账号、频道与媒体目录未完成。前一分钟控制有独立 Flutter 历史证据。本轮保留按音视频流替换响应、有界等待及缓存限制，增加新下载窗完成预取后再返回和 30 秒 HTTP 超时。只解码模式下，中点及回退有通过记录，片尾持续播放仍失败；合成视频绕开 Flutter 纹理后正常前进，具体输出原因尚未证实，用户选择稍后前台人工验收。97 项单元/组件回归通过，试验的缓存等待参数及 4 MiB 下载窗已撤回。完整计时、失败状态与当前边界见 [Flutter 播放器](flutter-player.md)，本轮未部署 Worker。
