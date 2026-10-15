# TG Cine

<!-- impeccable:product-schema 1 -->

## Platform

adaptive

## Stack

Flutter / Dart，UI 使用用户指定的 ForUI；Cloudflare Worker 使用 TypeScript。后续 Telegram 接入使用 TDLib；不使用 Go。

## Product Purpose

开源个人电影与电视剧播放器，以用户自己的 Telegram 账号可访问的媒体为来源。

面向所有用户，使用默认中转服务，无需邀请码或手工配置服务地址；用户主动选择已有权限的频道或群，核心闭环为找片、播放与本机续看。允许联网补全影视资料，保留待整理条目与来源追溯。手机与宽屏同步适配：首页为续看区与海报片库，宽屏提供详情预览。

已确认的目标方案见 [产品设计方案](docs/product-design.md)。以 App Store 公开发行作为设计目标，首发面向海外地区，不含中国大陆；媒体授权、Telegram 接入条款、隐私与审核条件须验证。此处记录产品目标，不代表这些能力已实现或审核已通过。

## Capabilities and Constraints

产品目标覆盖 Android、iOS、Web、Windows、macOS、Linux 六个平台；通过 flutter create 保留官方模板，手机与宽屏界面须同步设计、实现和验证。Android 与 iOS 同步实现共用登录与来源流程；模板、共用代码和打包入口不代表各平台已通过真机验收。
当前已实现四项响应式导航、真实空状态、本机外观设置、应用内 Telegram 授权步骤和来源选择，以及受限 Worker/Dart 桥接和本地联调。原生客户端已增加内置默认服务：公开地址/官方动态网段策略、独立设备访问凭据、刷新/撤销、持久日额度与并发限制。构建注入项目 Telegram 应用标识，并打包对应 TDLib；未准备好的平台保留不可用状态。Windows Debug 可以保留现有开发会话目录，同时改用默认服务凭据；公开构建不携带开发中转令牌。阶段状态见 docs/development-plan.md。
Worker 仓库默认关闭中转；已获授权部署到 `tg-cine.zhangheng.eu.org`，仅允许自动获取的 Telegram 官方公网网段及固定端口 443。公共默认服务的配置、设备签发/刷新/撤销及公共凭据五个 DC 握手已在线验证；Windows 应用用默认服务恢复登录并保留原 25 条片库数据。随后连接入口补齐一个实际固定目标及未完成退出的恢复，用户确认手机号页可见；全量 230 项测试通过，详见 docs/public-service.md。Android 原生库、真机默认中转及完整手机号/验证码/两步验证授权已通过；真实移动来源重开/导入、iOS 原生与播放仍待验收。动态策略增量全量 234 项 Flutter、64 项 Worker 测试通过，见 docs/telegram-network-policy.md。
Windows TDLib 已经应用内桥接和该 Worker 完成五个 DC 临时密钥握手；初始化、代理 ping、DPAPI 保护、本机账号授权与 `getMe` 已验证，重新打开会话也通过。本轮 Windows Data 层真实 `getMe`、主列表和归档读取已通过两次重开检查；不输出账号或来源标识。
Flutter 来源页按 Telegram 状态提供手机号、验证码、两步验证密码、邮箱及邮箱验证码输入，登录后搜索已加载的来源、逐项选择、加载更多并保存本机选择。搜索保留已选来源，退出登录要求再次确认；关闭应用保留登录。来源选择已迁入按账号隔离的独立加密 SQLite；Windows DPAPI、Android/iOS 系统安全存储保护独立媒体密钥，旧选择记录保留并按账号迁移一次。消息/实际版本、事务检查点与版本进度存储基础已实现，Android 真机和 Windows 的隔离数据库重开验收通过，iOS 待原生验收；见 docs/local-media-data.md。保存来源后可从片库手动开始历史分页导入，按批保存真实文件元数据，支持暂停/继续、文件名/说明/来源搜索、手机独立详情与宽屏预览、复制源消息链接。后台停止导入，返回前台不自动继续；观看记录仍为空状态，未接入播放器进度。见 docs/library-import.md。
Flutter 已接入 Windows Debug 播放器，使用本机工具提供的私有媒体源；ForUI 页面支持播放控制和响应式布局，与应用内来源选择独立。默认服务的连接状态与 Telegram 登录状态分开显示；线上启用以 docs/public-service.md 的实测记录为准，不提供虚构影片。本轮已停止播放排查，不新增真实播放验收结论；已有验证记录见 docs/flutter-player.md。
登录/来源阶段的 146 项 Flutter 测试、Android Debug APK 构建及 Windows 原生 Flutter 设计数据集成流程通过；本机数据基础后 159 项测试通过；历史导入增量后全量 199 项测试及静态分析通过。Windows 真实授权来源两次独立批次共保存 25 个媒体条目，重开后检查点继续推进，历史尚未结束；不读取视频字节。Android 真机与 Windows 的协议替身＋加密存储＋Flutter 导入、去重及重开恢复流程通过，不能代替真实移动 Telegram 导入。32 张登录/来源截图覆盖手机与宽屏、Android/iOS 平台变体、明暗主题和 1.0/2.0 字体缩放；这些是 Windows Flutter 渲染的设计数据画面，不是 iOS 模拟器或真机截图。Android 真机设计数据 UI 流程与系统安全存储隔离记录读写/删除已通过；iOS 签名构建与真机未运行。Android 两 ABI TDLib 已交付，真机默认服务完整授权验收通过；iOS 原生及真实移动来源恢复仍待验收，见 docs/mobile-native.md。
公共接入增量：全量 222 项 Flutter 测试、58 项 Worker 测试、Android 真机/Windows 的隔离凭据安全存储刷新与撤销通过。48 张默认服务截图覆盖手机/宽屏、明暗、字体缩放和 Android/iOS 平台变体，仍属于 Windows Flutter 设计数据，不能代替移动 Telegram 实测。目标是无需用户配置系统代理，各地区可达性仍须验证。

## Brand Commitments

使用 ForUI 组件。TG Cine 名称沿用仓库 tg-cine；产品名称尚未另行确认。
