> 历史 ADR（2026-10-12），固定目标、未接入和 v1 描述已被新版替代。当前设计见 [客户端架构](../architecture.md) 与 [目标策略](../telegram-network-policy.md)。

# ADR 0001：原生 TDLib 的中转可行性路径

状态：候选路径部分验证，2026-10-12。已部署实验版本，不是公开生产服务或六平台播放能力的确认。

## 选择

沿用 TDLib 的原生 SOCKS5 入口，以应用内 Dart 桥接连接受限 WSS Worker；Worker 只连接服务端白名单里的 TCP 目标。应用不修改操作系统代理，不把验证码、密码或序列化 Telegram 会话发送给 Worker。

```text
TDLib → 环回 SOCKS5 → Dart WebSocket → Worker connect() → Telegram TCP
```

Telegram DC 和媒体 DC 的实际地址/端口必须分别核验并配置为映射。桥接只将 ID 发送给 Worker，不能把 SOCKS 请求中的任意目的地址交给上游。网页不支持环回 TCP/SOCKS5，必须独立验证 tdweb/WASM 路线。

## 已验证与尚未验证

真实本机 workerd、Dart 桥接与 TCP echo 的 1 MiB 双向传输和关闭已通过。现有 TGvideo Node 原型的五个官方 WSS DC 握手也通过，但其 `/dc/<id>`、子协议鉴权与此处 `/v1/tunnel`、Bearer/ACK 契约不同，不能直接混用。

官方固定提交的 Windows x64 tdjson 已构建，Dart JSON ABI、初始状态与正常关闭验证通过。原生 `testProxy` 已经此桥接与线上 Worker 完成五个 DC 的临时密钥握手；初始化、启用代理及 `pingProxy` 通过，见 [原生验证](../native-tdlib.md)。用户在开发入口完成本机账号授权，`getMe` 和会话重开已验证；库仍未打包进 Flutter，视频读取未验收。新 Worker 十个固定目标的 Node 握手及自定义域名无代理访问另见 [部署记录](https://github.com/zhangheng2022/tg-cine-worker/blob/master/docs/history/worker-deployment.md)。逐帧 ACK 的吞吐与拖动体验待真实样本测量，生产窗口与配额不能依据握手或回环速度决定。

## 原型限制

传输默认关闭。启用后每连接双向合计 64 MiB、最长 15 分钟、空闲 30 秒；单帧 64 KiB、待写队列 256 KiB、连接超时 5 秒。桥接最多 6 条本机连接；仅为可行性验证，不是完整影片播放限制设计。

共享开发令牌只用于本机验证。公开默认服务需要独立短期凭证、撤销、持久配额/并发、Web 的专用握手和运营预算；现阶段不向 Flutter 客户端写入令牌或默认生产地址。

## 官方依据

- [Cloudflare TCP sockets](https://developers.cloudflare.com/workers/runtime-apis/tcp-sockets/)：connect() 出站 API，生产边缘限制私网/环回等目标；本地 echo 成功不替代边缘测试。
- [Cloudflare WebSockets](https://developers.cloudflare.com/workers/runtime-apis/websockets/)：WebSocketPair、关闭行为和 binaryType；本项目显式设置 arraybuffer，避免当前兼容日期的 Blob 默认行为改变处理方式。
- [TDLib SOCKS5 类型](https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1proxy_type_socks5.html) 与 [TDLib 构建](https://github.com/tdlib/td#building)：代理入口和原生库准备。
- [TDLib Web 示例](https://github.com/tdlib/td/tree/master/example/web)、[Telegram API 条款](https://core.telegram.org/api/terms)：网页路线与产品级行为要求。
