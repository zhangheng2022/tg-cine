# 默认服务客户端

默认服务地址仍为 `https://tg-cine.zhangheng.eu.org`。v2 Worker 已于 2026-10-15 上线，当前客户端只使用 v2，旧版客户端无法继续连接。服务端代码、配额与部署归属 [tg-cine-worker](https://github.com/zhangheng2022/tg-cine-worker)。

客户端通过 `GET /v2/config` 获取官方动态 CIDR 策略与同源 WSS 地址，通过 `POST /v2/devices` 激活，`/v2/devices/refresh` 刷新，`/v2/devices/revoke` 撤销。访问凭据仅在内存，刷新凭据由系统安全存储按域名、端口及 v2 隔离。

首次取得新版凭据时删除同服务的旧 v1 中转凭据；不读取或转换旧凭据，不删除 Telegram 会话、媒体数据库和观看记录。新版失效凭据不会静默循环注册，用户通过现有重新连接入口处理。

原生客户端在每次连接前取得访问凭据，通过 Authorization 发送，禁止凭据进入 URL，不跟随接口重定向。服务器独立校验目标与配额。详见 [协议](https://github.com/zhangheng2022/tg-cine-worker/blob/master/docs/protocol.md)。

## 本机构建

从仓库根运行 `dart run tool/prepare_public_config.dart <project-api-env>`，生成已忽略的 `.cache/deployment/flutter-public-defines.json`。该文件只含项目 Telegram 应用标识；不含共享中转令牌或账号会话。

```powershell
flutter build apk --debug --dart-define-from-file=.cache/deployment/flutter-public-defines.json
```

TDLib 安装与校验见 [移动原生构建](mobile-native.md)。Windows Debug 可以通过原有本机配置保留开发会话；这些路径不是公开构建输入。2026-10-15 已验证客户端真实配置解析、临时设备激活/刷新/撤销及 TDLib 经 v2 中转的五个 DC 握手，使用模拟安全存储隔离临时凭据，没有读取现有账号库。Android Debug 和 Windows Release 公开配置构建通过；未安装覆盖设备，整部影片播放和真机数据恢复尚未验收。

2026-10-15：Worker 本地已按用户要求取消播放配额，尚未部署，线上仍执行旧额度。客户端不依赖公开 limits 字段，保留请求受限提示和本机资源保护；诊断和验证见 [播放器记录](flutter-player.md)。

随后按用户追加确认，客户端应用内 6 连接、4 小时、累计传输与 Range 次数限制也已取消；每连接流控、回环校验、媒体缓存及等待队列等内存保护保留。Worker 未部署，旧线上额度仍可能拦截真实播放。
