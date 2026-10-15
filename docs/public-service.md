# 默认服务客户端

默认服务地址仍为 `https://tg-cine.zhangheng.eu.org`。当前客户端只使用 v2；必须与新版 Worker 一起发布，不能连接旧版服务。服务端代码、配额与部署归属 [tg-cine-worker](https://github.com/zhangheng2022/tg-cine-worker)。

客户端通过 `GET /v2/config` 获取官方动态 CIDR 策略与同源 WSS 地址，通过 `POST /v2/devices` 激活，`/v2/devices/refresh` 刷新，`/v2/devices/revoke` 撤销。访问凭据仅在内存，刷新凭据由系统安全存储按域名、端口及 v2 隔离。

首次取得新版凭据时删除同服务的旧 v1 中转凭据；不读取或转换旧凭据，不删除 Telegram 会话、媒体数据库和观看记录。新版失效凭据不会静默循环注册，用户通过现有重新连接入口处理。

原生客户端在每次连接前取得访问凭据，通过 Authorization 发送，禁止凭据进入 URL，不跟随接口重定向。服务器独立校验目标与配额。详见 [协议](https://github.com/zhangheng2022/tg-cine-worker/blob/main/docs/protocol.md)。

## 本机构建

从仓库根运行 `dart run tool/prepare_public_config.dart <project-api-env>`，生成已忽略的 `.cache/deployment/flutter-public-defines.json`。该文件只含项目 Telegram 应用标识；不含共享中转令牌或账号会话。

```powershell
flutter build apk --debug --dart-define-from-file=.cache/deployment/flutter-public-defines.json
```

TDLib 安装与校验见 [移动原生构建](mobile-native.md)。Windows Debug 可以通过原有本机配置保留开发会话；这些路径不是公开构建输入。新版线上与真机结果须在部署后记录，本次拆仓不复用 v1 成功记录作为 v2 验收。
