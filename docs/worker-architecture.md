# Worker 架构

`worker/` 与 `app/` 并列，使用官方 Worker-only TypeScript 模板。仓库默认关闭实验传输；2026-10-12 经用户授权部署线上启用版本，实际配置与边缘握手结果见 [部署记录](worker-deployment.md)。Windows 本机账号授权已通过，公共默认服务与播放尚未通过验收。

## 模块与调用方向

```text
index.ts   方法与路由识别、健康检查
  tunnel.ts   authorize → readTargetId → resolveTarget → Upgrade → 开关
    relay.ts   白名单 TCP 连接、WebSocket 转发、流控与清理
auth.ts       独立 Bearer 凭据校验
protocol.ts   协议版本、查询参数和脱敏错误
targets.ts    服务端目标白名单
test/         Vitest Workers 运行时测试
scripts/verify-local-relay.mjs   Dart / workerd / TCP 联调
```

采用原生 `fetch` 路由，不引入框架、数据库或依赖容器。鉴权先于参数和目标校验；客户端只能选择目标 ID，不能提交 hostname、port 或 URL。查询只允许各一个 `v=1`、`target`，重复或未知参数被拒绝。

## 接口与配置

| 接口 | 行为 |
| --- | --- |
| `GET /health` | 返回服务状态、协议版本和 `capabilities.tunnel` 开关值；不代表上游连通 |
| `GET /v1/tunnel?v=1&target=<ID>` | 要求 Bearer、合法参数、白名单目标和 WebSocket Upgrade；关闭时返回 `501 / TUNNEL_NOT_IMPLEMENTED`，启用后连接上游成功才返回 `101`；连接失败或超时返回脱敏 `502` |

| 配置 | 来源与约束 |
| --- | --- |
| `RELAY_TOKEN` | 独立开发凭据，本地 `.dev.vars` 与部署用凭据文件保持忽略；线上通过 Worker Secret 配置，不能与 Telegram 会话共用或打包进公开客户端 |
| `RELAY_TARGETS` | 非敏感 JSON 字符串，ID 映射 `{hostname, port}`；默认 `{}`，由服务端预设并验证实际归属 |
| `RELAY_ENABLED` | 仅字符串 `"true"` 开启实验传输；`wrangler.jsonc` 默认 `"false"` |

`false` 不跳过其他校验。不得把令牌写入 URL、源码、日志或提交的 Wrangler 配置。健康检查和错误不输出目标、凭据或上游异常内容。

## 实验传输契约

WebSocket 显式使用 `arraybuffer`：数据帧为非空二进制；文本只允许预期中的字面量 `ACK`。客户端将每帧交给本机 TCP 并 flush 后回复 ACK；Worker 下行允许窗口内多帧连续发送，按 FIFO 确认释放对应字节，窗口满时停止读取上游。协议仍为 v1，兼容现有逐帧确认客户端。上行仍由客户端每发送一片等待 Worker 写入上游后的 ACK。握手成功不代表媒体可播。

| 限制 | 当前值 |
| --- | --- |
| 单帧 / 上游待写队列 | 64 KiB / 256 KiB |
| 下行未确认窗口 | 256 KiB，同时最多 64 帧 |
| 双向累计 / 单连接最长时间 | 64 MiB / 15 分钟 |
| 连接 / 空闲超时 | 5 秒 / 30 秒 |
| 最老下行帧确认超时 | 30 秒，不因其他活动延后 |

上游 EOF 后等待已发送帧全部确认再关闭；异常 ACK、帧或队列违规、流量/时间超限及上游失败会关闭双方、解除窗口等待、取消读写和清理计时器。以上是有界可行性保护，不是公开用户的持久配额；共享令牌无法提供账号隔离、撤销和总并发治理。

## 原生桥接与平台边界

`app/lib/data/services/relay/relay_bridge.dart` 只监听 IPv4 环回地址，提供实验 SOCKS5 CONNECT，最多 6 条本机连接。请求地址必须精确映射为配置中的目标 ID，未知地址拒绝；桥接通过 WSS Authorization 发送令牌，不设置系统代理。入口工具为 `app/tool/relay_bridge.dart`，凭据由本机令牌文件读取。

此桥接未接入 Flutter 登录；Windows TDLib 独立 ABI、经此桥接与线上 Worker 的五个 DC 临时密钥握手、初始化、代理 ping、真实账号授权及重开后的 `getMe` 已通过。媒体读取和播放等待所选样本验证。Web 不能使用 `dart:io` 或环回 SOCKS5，浏览器 WebSocket 也不能自定义 Authorization，因此需要独立协议适配。详见 [原生中转 ADR](adr/0001-native-relay.md)。

## 开发与验证

在 `worker/` 使用 Node.js 24 执行 `npm ci`。本地 `.dev.vars` 可从 `.dev.vars.example` 复制；空白名单拒绝所有目标。`npm run dev` 强制本地运行。

```powershell
npm run format:check
npm run check
npm test
npm run build
npm run test:relay
```

`check` 生成已忽略的 Wrangler Env 类型并检查源码/测试；`test` 为 Vitest 非监听运行。`build` 仅 dry-run 打包到 `dist/`，不部署。

`test:relay` 另需先在 `app/` 执行 `flutter pub get`；它创建临时令牌、本地 TCP echo 和本地 workerd，运行 Dart SOCKS5 桥接，检查 1 MiB 字节顺序与内容及正常退出，并清理自己的临时配置。仅测试夹具将随机令牌写入已忽略的临时配置，不修改项目默认开关。生产边缘限制环回/私网地址，不能将此测试白名单部署。

CI 包含独立 Worker 检查和 Flutter 作业中的组合联调，没有部署步骤或 Cloudflare 凭据。`.wrangler/`、`.dev.vars`、生成类型和构建产物保持忽略。本地运行、原型握手和 dry-run 均不证明边缘 TCP、Telegram 登录、长时间播放、费用或远程 CI 通过。
