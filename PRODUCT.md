# TG Cine

<!-- impeccable:product-schema 1 -->

## Platform

adaptive

## Stack

Flutter / Dart，UI 使用用户指定的 ForUI；服务端由独立 tg-cine-worker 仓库使用 TypeScript / Hono 维护。Telegram 接入使用 TDLib；不使用 Go。

## Product Purpose

开源个人电影与电视剧播放器，以用户自己的 Telegram 账号可访问的媒体为来源。

面向所有用户，使用默认中转服务，无需邀请码或手工配置服务地址；用户主动选择已有权限的频道或群，核心闭环为找片、播放与本机续看。允许联网补全影视资料，保留待整理条目与来源追溯。手机与宽屏同步适配：首页为续看区与海报片库，宽屏提供详情预览。

已确认的目标方案见 [产品设计方案](docs/product-design.md)。以 App Store 公开发行作为设计目标，首发面向海外地区，不含中国大陆；媒体授权、Telegram 接入条款、隐私与审核条件须验证。此处记录产品目标，不代表这些能力已实现或审核已通过。

## Capabilities and Constraints

当前实现与验收边界更新于 2026-10-15；历史测试数量和设备记录保留在对应验收文档，不在此累积。

产品目标覆盖 Android、iOS、Web、Windows、macOS、Linux 六个平台。当前原生 Telegram 接入面向 Android、iOS、Windows；Web、macOS、Linux 保留工程与界面，不代表 Telegram 业务可用。Android 与 iOS 的共用登录和来源流程同步维护；手机与宽屏界面须同步设计、实现和验证。

已实现四项响应式导航、本机外观设置、应用内 Telegram 授权与来源选择。来源页支持手机号、验证码、两步验证密码、邮箱及邮箱验证码；搜索保留已选来源，退出登录要求确认，关闭应用保留会话。默认服务状态与 Telegram 登录状态分开显示。原生构建注入项目应用标识并打包对应 TDLib，公开客户端不携带共享开发中转令牌。

本机来源和片库使用按账号隔离的加密 SQLite，密钥由 Windows DPAPI 或 Android/iOS 系统安全存储保护。历史分页导入支持事务检查点、暂停/继续、文件名/说明/来源搜索、响应式详情和按消息能力复制源链接。后台停止导入，返回前台不自动继续；媒体身份使用实际文件版本，不用文件名。实现与历史证据见 [本机数据](docs/local-media-data.md)、[历史导入](docs/library-import.md)。

[阶段验收](docs/library-acceptance.md)记录了拆仓前 Android 真实授权、片库导入与重开恢复，以及 Windows 本机数据和 iOS 模拟器原生/隔离存储、导入流程；iOS 带框架无签名设备构建已通过，签名 iPhone 真机业务仍待验收。设计数据截图与平台变体不等于对应平台真机证据。这些历史结果不替代 v2 升级后的设备验收。

客户端与独立 Worker 只使用 v2。2026-10-15 的服务发布、旧状态清理、接口及五个 DC 握手证据统一见 [Worker 发布记录](https://github.com/zhangheng2022/tg-cine-worker/blob/master/docs/deployment.md)；仓库默认服务关闭与该次线上发布是不同状态。客户端接入和公开配置构建见 [默认服务](docs/public-service.md)。真机升级后的会话/片库恢复及各地区可达性尚需独立验证。

Windows Debug 播放器使用私有开发媒体源，与片库选择独立；正式片库播放、观看记录和续看尚未接线。数据库已有进度存储接口，不代表产品闭环已完成。完整影片播放仍未验收，历史记录见 [播放器接入](docs/flutter-player.md)。

## Brand Commitments

使用 ForUI 组件。TG Cine 名称沿用仓库 tg-cine；产品名称尚未另行确认。

## 2026-10-15 仓库拆分

当前仓库只保留客户端，Flutter 位于根目录；服务端、Cloudflare/Hono 技能与运维文档独立维护。拆仓及后续已授权发布的边界见 [迁移说明](docs/repository-split.md)；后续部署仍需另行授权。
