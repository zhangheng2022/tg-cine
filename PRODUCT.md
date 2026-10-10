# TG Cine

<!-- impeccable:product-schema 1 -->

## Platform

android, ios, web, windows, macos, linux

## Stack

Flutter / Dart，UI 使用用户指定的 ForUI；Cloudflare Worker 使用 TypeScript。后续 Telegram 接入使用 TDLib；不使用 Go。

## Product Purpose

开源个人电影与电视剧播放器，以用户自己的 Telegram 账号可访问的媒体为来源。

## Capabilities and Constraints

不限制平台；通过 flutter create 生成六个平台的官方模板，手机端界面优先。
当前范围为 Flutter 项目初始化、参照 meet_trace 的分层 MVVM、ForUI 基础界面，以及 Worker 基础架构、校验、测试和 CI；模板存在不表示已完成各平台功能适配。
Worker 只提供健康检查和中转入口校验，真实中转明确不可用，未部署。
尚未实现 Telegram 登录、视频播放或 Cloudflare 中转，界面不得声称已连接或提供虚构影片。
目标是无需用户配置系统代理；实际网络可达性尚待验证。

## Brand Commitments

使用 ForUI 组件。TG Cine 名称沿用仓库 tg-cine；产品名称尚未另行确认。
