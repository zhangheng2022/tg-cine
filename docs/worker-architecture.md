# Worker 基础架构

`worker/` 与 `app/` 并列，使用官方 `create-cloudflare` 的 Worker-only TypeScript 模板。
当前只初始化请求边界、测试和 CI，不建立 Telegram 连接、不升级 WebSocket、不部署。

```text
worker/
  src/
    index.ts             fetch 入口与路由
    auth.ts              中转凭据校验
    protocol.ts          协议版本、请求与错误契约
    targets.ts           服务端目标白名单校验
    tunnel.ts            校验后的中转入口，当前返回 501
  test/                  Vitest Workers 运行时测试
  wrangler.jsonc         本地运行配置与非敏感变量
  worker-configuration.d.ts  Wrangler 生成的运行时与 Env 类型（已忽略）
  package.json           本地开发、检查、测试与 dry-run 构建
  package-lock.json      npm 依赖锁文件
  .dev.vars.example      无真实凭据的本地配置示例
```

采用原生 `fetch` 路由，不引入框架、数据库或空依赖容器。
入口依次执行方法与路由识别、鉴权、协议和目标校验，再进入中转处理。
目标白名单默认留空，客户端输入不能替代服务端允许的目标。

| 接口 | 当前行为 |
|---|---|
| `GET /health` | 返回 `service: tg-cine-worker`、`status: ok`、`protocolVersion: 1` 与 `capabilities.tunnel: false`；不代表 Telegram 连通 |
| `GET /v1/tunnel?v=1&target=<目标 ID>` | 要求 `Authorization: Bearer <token>` 和 `Upgrade: websocket`；校验通过仍返回 `501 / TUNNEL_NOT_IMPLEMENTED`，不会升级或建立上游连接 |

查询参数只允许单个 `v` 和单个 `target`，禁止重复参数和其他参数；不接受 URL 凭据，也不接受客户端提供的 hostname、port 或 URL。
这只是原生端的初始化握手验证契约。浏览器 WebSocket 无法自定义 `Authorization`，Web 端需要后续独立鉴权适配，当前接口不表示浏览器中转可用。

| 配置 | 来源与约束 |
|---|---|
| `RELAY_TOKEN` | 中转独立凭据；本地 `.dev.vars`，将来部署时使用 Worker Secret；不与 Telegram 会话共用 |
| `RELAY_TARGETS` | 非敏感 JSON 对象字符串，目标 ID 映射 `{hostname, port}`；默认 `{}`，只能由服务端预设 |

错误使用固定代码和明确的 HTTP 状态，不返回凭据或配置内容。
凭据只来自本地 `.dev.vars` 或将来单独配置的 Worker Secret，不能写入 URL、源码或 `wrangler.jsonc`。
Telegram 验证码、密码、会话与媒体均不进入本初始化工程。

后续接入真实传输时，再实现 WebSocket 首帧握手、流控、队列与帧大小限制、超时和双端清理；当前接口不能作为可用中转服务。
Flutter 接入保持既有调用方向，通过 Domain Port 与 Data Service 实现，不从 UI 直接访问 Worker。
原生端本地桥接和 Web 端传输适配均待后续验证。

## 开发与验证

使用 Node.js 24，在 `worker/` 执行 `npm ci`，将 `.dev.vars.example` 复制为已忽略的 `.dev.vars` 后填写本地 `RELAY_TOKEN`。
空白名单会拒绝所有目标；白名单中的地址是否属于 Telegram 和能否连接，需在后续真实传输接入时验证。
`npm run dev` 使用本地 Wrangler；健康检查可用于确认本地服务启动。

```powershell
npm run format:check
npm run check
npm test
npm run build
```

`types` 执行 `wrangler types --strict-vars=false`，根据配置及 required Secret 声明生成 `Env` 类型；生成文件保持忽略。
`check` 先生成类型，再执行源码与测试的 TypeScript 检查；测试使用 Vitest Workers 运行时，`test` 为非监听模式的 `vitest run`。
`build` 仅执行 `wrangler deploy --dry-run` 并输出到 `dist/`；没有部署脚本。
CI 保留 Flutter 任务，并独立执行 Worker 的上述检查，使用 Node.js 24 和 `npm ci` 安装锁定依赖，关闭 Wrangler 遥测，不注入 Cloudflare 凭据。

构建产物、`.wrangler/`、`.dev.vars` 与本地环境文件均应保持忽略。
本地测试与 dry-run 不证明边缘环境、网络可达性、Telegram 连接或长时间播放可用；远程 CI 也需实际运行后才能确认。
