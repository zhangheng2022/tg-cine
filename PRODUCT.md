# TG Cine

<!-- impeccable:product-schema 1 -->

## Platform

android, ios, web, windows, macos, linux

## Stack

Flutter / Dart，UI 使用用户指定的 ForUI；Cloudflare Worker 使用 TypeScript。后续 Telegram 接入使用 TDLib；不使用 Go。

## Product Purpose

开源个人电影与电视剧播放器，以用户自己的 Telegram 账号可访问的媒体为来源。

面向所有用户，使用默认中转服务，无需邀请码或手工配置服务地址；用户主动选择已有权限的频道或群，核心闭环为找片、播放与本机续看。允许联网补全影视资料，保留待整理条目与来源追溯。手机与宽屏同步适配：首页为续看区与海报片库，宽屏提供详情预览。

已确认的目标方案见 [产品设计方案](docs/product-design.md)。以 App Store 公开发行作为设计目标，首发面向海外地区，不含中国大陆；媒体授权、Telegram 接入条款、隐私与审核条件须验证。此处记录产品目标，不代表这些能力已实现或审核已通过。

## Capabilities and Constraints

不限制平台；通过 flutter create 生成六个平台的官方模板，手机与宽屏界面须同步设计、实现和验证。
当前已实现四项响应式导航、真实空状态、本机外观设置，以及受限 Worker/Dart 桥接和本地联调；模板存在不表示已完成各平台功能适配。阶段状态见 docs/development-plan.md。
Worker 仓库默认关闭中转；实验版本已获授权部署到 `tg-cine.zhangheng.eu.org`，本机无代理 HTTPS 及十个固定 Telegram 目标的边缘握手已验证。公共服务鉴权与配额未实现，真实播放仍待验收。
Windows TDLib 已经应用内桥接和该 Worker 完成五个 DC 临时密钥握手；初始化、代理 ping、DPAPI 保护、本机账号授权与 `getMe` 已验证，重新打开会话也通过。频道/视频选择开发入口已实现，不能将这些工具计为 Flutter 登录与来源功能。
Flutter 已接入 Windows Debug 播放器，使用本机工具持有的 Telegram 授权与私有媒体源；ForUI 页面支持播放控制和响应式布局。应用内登录、频道选择、片库和默认公共服务尚未接入，界面须明确开发边界，不提供虚构影片。验证记录见 docs/flutter-player.md。
目标是无需用户配置系统代理；实际网络可达性尚待验证。

## Brand Commitments

使用 ForUI 组件。TG Cine 名称沿用仓库 tg-cine；产品名称尚未另行确认。
