# Worker 实验部署记录

更新时间：2026-10-14。用户已明确授权部署及优化执行；本次部署工作区中的实验实现，未提交 Git，也未修改既有 TGvideo Worker。

2026-10-14 部署脱敏播放计时，版本 `0e133901-bbc3-4067-bc4d-94aea5b8f7ff`；已核对该版本承接 100% 流量及对应源码摘要。49 项运行时测试、类型检查和实际配置 dry-run 通过。只增加随机连接标识和关闭时的数字统计；配额、白名单和域名不变。线上 tail 连接超时，尚未获得同轮边缘统计；以下握手与域名检测是此前记录，不视作本轮重新验收。详见 [稳定性验证](playback-stability.md)。

## 服务与配置

- Worker：`tg-cine-worker`；版本：`466e7289-959b-4437-bb97-7ce884690ed9`，100% 流量。
- 自定义域名：[https://tg-cine.zhangheng.eu.org](https://tg-cine.zhangheng.eu.org/health)，使用用户确认的项目子域名；临时 `tg-cine.huiyunda.pl` 绑定已移除。
- 默认地址：[https://tg-cine-worker.zhangheng.workers.dev](https://tg-cine-worker.zhangheng.workers.dev/health)。
- 中转入口：`wss://tg-cine.zhangheng.eu.org/v1/tunnel?v=1&target=<ID>`，需 `Authorization: Bearer <本机令牌>`；逐帧 ACK 契约见 [Worker 架构](worker-architecture.md)。
- 线上 `RELAY_ENABLED=true`；仓库默认配置仍为 `false` 和空白名单。日志开启，trace 采样为 1%；Preview URL 关闭。

仅允许以下固定公共 IPv4 目标；包含 TDLib 预设地址和运行时实际选择的四个补充地址。媒体 DC 的实际列表仍需取样核对。

| ID | 地址 / 端口 |
| --- | --- |
| dc1 | 149.154.175.50:443 |
| dc2 | 149.154.167.51:443 |
| dc2_backup | 95.161.76.100:443 |
| dc3 | 149.154.175.100:443 |
| dc4 | 149.154.167.91:443 |
| dc5 | 149.154.171.5:443 |
| tg_149_154_175_54 | 149.154.175.54:443 |
| tg_91_108_56_122 | 91.108.56.122:443 |
| tg_91_108_56_183 | 91.108.56.183:443 |
| tg_91_108_56_175 | 91.108.56.175:443 |

预设目标来自 [TDLib 固定提交的 ConnectionCreator.cpp](https://github.com/tdlib/td/blob/c15d3f5a5de6e3ba5839822c451152e5e18bb700/td/telegram/net/ConnectionCreator.cpp)。补充目标由本机 TDLib 连接诊断获得，核对 [Telegram 官方地址范围](https://core.telegram.org/resources/cidr.txt) 后逐项部署并验证握手；没有开放整个 CIDR 或动态任意转发。曾误读的 `91.108.56.12` 已从线上和本机映射移除，验证返回 `403`。服务上限保持每连接双向合计 64 MiB、15 分钟、30 秒空闲、64 KiB 单帧和 256 KiB 上游待写队列；下行窗口为 256 KiB / 64 帧，最老帧确认期限为 30 秒。这是开发验证服务，不是公开用户的默认生产服务。

## 本机文件与再次部署

下列文件位于已忽略的 `.cache/deployment/`，不随仓库克隆提供：

- `wrangler.json`：实际账号、域名、开关和目标配置；包含当前部署对应的源码入口。
- `secrets.json`、`relay-token.txt`：独立随机开发令牌；Windows ACL 仅允许当前用户和 SYSTEM。令牌作为 Cloudflare Secret 上传，不写入客户端、URL、源码或本记录。
- `relay-bridge.json`：Dart 桥接的 WSS 地址与目标映射。
- `deployment-manifest.json`、`edge-probe.json`：不含密钥的版本、源码摘要与协议验收结果。

在 `worker/` 内使用本项目 Wrangler 4.149.0：

```powershell
npx.cmd wrangler deploy --config ../.cache/deployment/wrangler.json --secrets-file ../.cache/deployment/secrets.json --strict --no-autoconfig
npx.cmd wrangler deployments list --name tg-cine-worker --json
npx.cmd wrangler secret list --name tg-cine-worker
```

不要直接用默认 `wrangler.jsonc` 覆盖线上启用配置。`npm run build` 继续只 dry-run，CI 没有自动部署步骤。上传代码与 Secret 使用官方 [secrets-file](https://developers.cloudflare.com/workers/configuration/secrets/#upload-secrets-alongside-code)；自定义域名创建前检查 changeset，仅新增此域名，不覆盖既有 origin 或 DNS。域名绑定方式见 [Cloudflare Custom Domains](https://developers.cloudflare.com/workers/configuration/routing/custom-domains/)。

需要紧急停止新中转时，在同一实际配置上部署 `--var RELAY_ENABLED:false`；已有连接的立即撤销能力尚未实现。首次部署没有可回退的旧项目版本，后续回滚须记录版本 ID 并核对配置和 Secret，不能只依据 Git HEAD。

## 验收结果与限制

2026-10-13 已执行下行窗口优化，线上流量和本机源码摘要与部署清单一致。48 项 Workers 测试、类型、格式、打包、实际配置 dry-run 及 1 MiB 逐字节 workerd 回环通过；本地源码审查覆盖字节/帧数边界、FIFO 空间释放、EOF 确认、确认超时与关闭清理。保持原客户端读取逻辑，对同一大样本冷读取两个 512 KiB 范围，从 48.7 / 56.3 秒降至 2.59 / 1.39 秒，连续 1 MiB 从 70.2 秒降至 2.71 秒；这是单样本前后对照。随后加入本机连续预取、索引准备与旧读取取消，VLC 首张 PNG 两轮约 14.7 / 7.3 秒，详见 [原生验证](native-tdlib.md)。旧版本 `4bd39257-ad3e-406e-94a7-be8bcbe8cc70` 与原数值报告保存在已忽略的 `.cache/relay-window/`，不依据 Git HEAD 回滚。

部署前格式、类型检查、43 项 Workers 运行时测试及实际配置 dry-run 均通过；部署后 `/health` 返回 `200`、`protocolVersion=1`、`tunnel=true`。未鉴权返回 `401`，未知目标 `403`，缺少 Upgrade `426`，额外查询参数 `400`。

本机 `curl --noproxy "*"` 请求自定义域名返回 `200`；同样方式请求 workers.dev 在 15 秒内超时。因此桥接配置使用自定义域名，不把带默认代理配置的 HTTPS 成功计为直连证据。

最新显式直连 Node Agent 经用户指定域名和新 Worker 的 WSS/TCP 中转，在十个白名单目标均完成 `req_pq_multi → resPQ` 并校验 nonce，耗时 1934–3435 ms。默认系统 DNS 下的无代理 HTTPS 和 WSS 均通过，没有修改系统 DNS 或代理设置。该协议探测未读取 Telegram 凭据、未登录账号、未读取媒体；此前 TGvideo 原型的结果没有替代这次新 Worker 的验证。

协议依据为 [Telegram MTProto transports](https://core.telegram.org/mtproto/mtproto-transports)。协议探测证明本次网络下的边缘 TCP 与握手，不能单独证明账号授权、视频首播/拖动、持续吞吐、所有地区可达、公共服务配额或费用可控。

Windows TDLib→Dart SOCKS5/WSS→同一线上 Worker 的五个 DC 临时密钥握手与代理 ping 已通过。此次仅调整线上目标配置，Worker 源码未改变；用户在本机完成账号授权，`getMe` 已验证，重新打开会话也通过。媒体读取与播放仍待所选样本验收，见 [原生验证与登录入口](native-tdlib.md)。
