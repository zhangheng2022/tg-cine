# 客户端目标策略

`TelegramTargetPolicy` 从 `/v2/config` 读取服务端获取的 Telegram 官方 CIDR、更新时间与到期时间。只接受公网 IPv4/IPv6 与端口 443；目标编码为 `ip4_<8位小写十六进制>` 或 `ip6_<32位小写十六进制>`。

策略一小时有效，到期前 30 秒更新，合并并发配置读取。错误或过期策略拒绝新连接，不回退固定 IP。客户端校验不能替代服务端校验。

服务端抓取、缓存、安全边界和协议统一在 [Worker 协议文档](https://github.com/zhangheng2022/tg-cine-worker/blob/master/docs/protocol.md) 维护。客户端测试位于 `test/data/services/relay/`；历史 v1 部署证据已迁往服务端仓库 `docs/history/`，不代表新版上线。
