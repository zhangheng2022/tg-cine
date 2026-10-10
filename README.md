# TG Cine

**连接 Telegram 的个人影视库与播放器。**

TG Cine is an open-source prototype for a personal movie and TV player powered by Telegram.

目标是让用户添加自己能访问的影视频道或群组，在一个应用里找片、选集、播放和继续观看。
当前仓库是可运行的协议、测速与本机播放原型，尚未提供完整桌面影视库界面或安装包。
产品轮廓和未实现功能见 [Roadmap](docs/ROADMAP.md)。

## 当前功能

- 本机交互式 Telegram 登录，验证码与二次验证密码仅在本机终端输入。
- 从可访问会话及最近视频中选择播放样本。
- MTProto 分片读取、文件引用刷新和有限媒体 DC 迁移处理。
- 本机 HTTP Range / HEAD 接口、分片预取及最多 8 MiB 的已完成分片缓存。
- 浏览器播放页面与外部 VLC 播放入口；不转码。
- 同视频、同区间的 1 / 2 / 4 并发测速。
- Cloudflare Worker WSS 中继，固定 DC 白名单与共享令牌鉴权。
- 协议、访问控制、Range、缓存、取消及媒体读取自动化测试。

## 架构

```text
本机 Telegram 账号 / MTProto 客户端
                │
                ▼
       WSS → 自建 Cloudflare Worker → Telegram 官方 WSS
                │
                ▼
       本机 HTTP Range → 浏览器 / VLC
```

账号会话和视频缓存保留在本机进程内存。Worker 转发 MTProto 流量，不接收本机登录界面输入的验证码、密码或序列化会话。
本机播放服务仅监听 `127.0.0.1`，使用随机路径及 Host / Origin 校验。

## 环境要求

- Node.js 22 或以上；当前 CI 使用 Windows / Node.js 24。
- 自己的 Telegram API ID / API Hash：[创建应用](https://core.telegram.org/api/obtaining_api_id)。
- Cloudflare 账号及自己部署的 Worker 中继。
- 若浏览器不支持视频编码，可使用兼容的本机播放器，例如 VLC。

仓库不提供公共中继服务、Telegram 账号、影视内容或 VLC 二进制文件。

## 快速开始

以下命令使用 Windows PowerShell。使用 `npm.cmd` 可避免 PowerShell 对 `npm.ps1` 的执行策略限制。

### 1. 安装与首次配置

```powershell
git clone https://github.com/zhangheng2022/tg-cine.git
cd tg-cine
npm.cmd ci
Copy-Item -LiteralPath .env.example -Destination .env
Copy-Item -LiteralPath wrangler.example.jsonc -Destination wrangler.jsonc
npm.cmd test
npm.cmd run build
```

配置文件只在首次安装时复制；已有配置不要覆盖。
`build` 仅打包，不部署。`.env`、`.dev.vars`、`wrangler.jsonc`、结果和本机工具均被 Git 忽略。

### 2. 准备中继

生成本机中继令牌；文件已存在时命令会停止，避免覆盖正在使用的密钥：

```powershell
node --input-type=module -e "import {randomBytes} from 'node:crypto'; import {writeFileSync} from 'node:fs'; writeFileSync('.dev.vars', 'RELAY_TOKEN=' + randomBytes(32).toString('base64url') + '\n', {flag:'wx'});"
npx.cmd wrangler login
npx.cmd wrangler deploy
npx.cmd wrangler secret put RELAY_TOKEN
```

在 `secret put` 的本机提示中输入 `.dev.vars` 中相同的令牌，不要把密钥发到 Issue 或聊天。
若使用自定义域名，在自己的 `wrangler.jsonc` 配置 `routes`，可参考 [Cloudflare 自定义域名文档](https://developers.cloudflare.com/workers/configuration/routing/custom-domains/)。

### 3. 配置 Telegram 与入口

编辑本机 `.env`：

```dotenv
TG_API_ID=
TG_API_HASH=
RELAY_URL=wss://your-relay.example.com
RELAY_IP=
```

- 填入自己的 API ID / API Hash，及自己的 Worker HTTPS 域名对应的 `wss://` 地址。
- `RELAY_IP` 填该域名经核实的 1–4 个公网 IPv4 地址，以逗号分隔。
- 客户端固定连接这些地址，同时保留域名 TLS 证书校验；地址变化后需更新。
- 未提供自动 DNS 入口发现。入口是否可达取决于网络、域名和时段。

先验证五个 Telegram DC 的协议连接：

```powershell
npm.cmd run probe:direct
```

该命令通过你的 Worker 中继，连接时不配置本地 HTTP / SOCKS 代理。
协议探测仅验证 `req_pq_multi → resPQ`，不代表已完成账号登录或视频播放。

### 4. 播放与测速

```powershell
npm.cmd run play          # 登录、选择视频，打开本机播放页
npm.cmd run speed         # 同一区间的 1 / 2 / 4 并发测速
npm.cmd run verify:play   # 先主动关闭本进程媒体连接验证恢复，再启动播放
```

手机号、验证码和二次验证密码在本机交互终端输入，敏感输入显示星号。
播放结束后返回终端按回车或 Ctrl+C，程序关闭本机服务并尝试注销；注销未确认时，请在 Telegram 设置 → 设备中终止本次会话。
直接关闭窗口或强杀进程可能来不及注销。

VLC 应打开终端或网页给出的 **`/video` 视频流地址**，不能使用播放网页地址。
可选命令 `npm.cmd run play:native` 目前只支持 Windows，需要自行准备 `.tools/vlc/vlc-3.0.23/vlc.exe`；该目录不会提交。
关闭 VLC 后仍需在终端结束播放会话。

测试和播放报告保存在被忽略的 `results/`，不保存视频字节。不要直接公开未经检查的报告、截图或终端日志。

## 已知边界

- 当前只列出前 100 个会话及最近 10 条视频，尚未实现影视库、历史分页、追剧或持久化观看进度。
- 账号会话只保存在内存，尚未实现本机加密持久化。
- 浏览器支持的编码有限。已在本机样本中验证 VLC 可以显示 HEVC 10-bit 画面，不能据此保证所有设备和格式兼容。
- 缓存上限只指已完成分片，不包含预取、SDK、播放器和其他进程内存。
- 尚未实现 Telegram CDN 下载；不声明 `cdn_supported`，收到 CDN 重定向时停止读取。
- 限流会使测试停止；固定 IP 备用切换主要覆盖 TCP / TLS 连接失败，不完整覆盖 HTTP Upgrade 失败。
- 短时分片测速不等于持续播放、首帧、拖动体验或最大带宽；长时播放及跨网络可靠性仍需验收。
- 当前共享令牌中继没有多用户配额、独立凭证或撤销机制，不适合直接开放为公共服务。
- 受保护内容、自动删除消息及频道赞助消息的产品级处理尚未完成。

仅访问自己有权访问的内容。公开客户端发布前需完成 [Telegram API 条款](https://core.telegram.org/api/terms) 和 [内容保护要求](https://core.telegram.org/constructor/message) 对应的行为；开源许可证不授予影视内容的使用权。
中继的可用性、配额与费用应按 [Cloudflare Workers 官方说明](https://developers.cloudflare.com/workers/platform/pricing/) 评估，不承诺免费无限量或任何网络长期可达。

## 开发与贡献

```powershell
npm.cmd test
npm.cmd run build
```

CI 只运行测试和 dry-run 打包，不部署 Worker，不需要 Telegram 或 Cloudflare 凭据。
欢迎通过 Issue 描述问题及通过 Pull Request 提交改进；问题复现请提供版本、步骤和脱敏错误信息，不要上传手机号、验证码、密码、API Hash、中继令牌或账号会话。

| 路径 | 内容 |
| --- | --- |
| `worker.mjs` | 固定 Telegram WSS 中继与访问控制 |
| `scripts/` | 协议探测、分片读取、播放、测速及终端输入 |
| `test/` | 自动化测试 |
| `docs/ROADMAP.md` | 影视播放器产品方向 |
| `wrangler.example.jsonc` | 自建 Worker 配置模板 |

## 许可证

项目代码使用 [MIT License](LICENSE)。第三方依赖和外部播放器遵循各自许可证；仓库不包含它们的二进制发行包。
TG Cine 是使用 Telegram API 的独立开源项目，与 Telegram 官方无隶属关系。
