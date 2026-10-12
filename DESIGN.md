---
name: TG Cine
description: Flutter 跨平台初始化界面的 ForUI 默认视觉记录
colors:
  light-background: "#FFFFFF"
  light-foreground: "#0A0A0A"
  light-primary: "#171717"
  light-primary-foreground: "#FAFAFA"
  light-muted-foreground: "#737373"
  light-border: "#E5E5E5"
  dark-background: "#0A0A0A"
  dark-foreground: "#FAFAFA"
  dark-primary: "#E5E5E5"
  dark-primary-foreground: "#171717"
  dark-muted-foreground: "#A1A1A1"
  dark-card: "#171717"
  dark-border: "#FFFFFF1A"
typography:
  display: {fontFamily: "packages/forui/Inter", fontSize: "30px", lineHeight: 2.25}
  body: {fontFamily: "packages/forui/Inter", fontSize: "18px", lineHeight: 1.75}
rounded:
  md: "10px"
spacing:
  page-horizontal: "12px"
components:
  button-primary: {rounded: "{rounded.md}", padding: "14px 12px"}
---

# Design System: TG Cine

## Overview

沿用 ForUI 0.27.4 的 neutral light/dark touch 默认主题；本次未另行建立品牌视觉世界。不限制平台，手机与宽屏界面须同时适配，中文（zh_CN）界面，明暗模式跟随系统，图标使用 ForUI Lucide。
当前仅有片库、观看记录、设置三个初始化页面；Telegram 登录、播放和中转尚未接入。

## Colors

Primary 为主题的黑白主操作对比色；Neutral 用于页面、文字、说明与边框。前置 token 记录实际值；浅色设置容器与页面同色，深色设置容器使用 dark-card。运行时始终通过 `context.theme.colors` 获取颜色。

## Typography

使用 ForUI 默认 Inter，中文由平台字体回退显示，保留系统字体缩放。空状态标题为 `display.xl2`、说明为 `body.md`；根标题沿用 FHeader 默认粗体，按钮沿用 `body.sm`（16sp、500、行高 1），底部标签沿用 `body.xs3`（10sp、行高 1.5）。前置 px 仅是可移植记录，Flutter 字号按逻辑尺寸及字体缩放生效。

## Layout

FScaffold 保留默认横向内边距；FHeader 处理顶部安全区域，底部导航显式启用 `safeAreaBottom`。主体各页独立滚动；空状态以可用高度为最小高度居中，宽度最多 320dp、上下内边距 32dp，空间不足时可纵向滚动。空状态图标 48dp；顺序间隔为 24、12、28dp；主按钮约束最小高度 48dp。设置内容顶部留 16dp。当前实现未设置桌面断点；后续布局按可用窗口宽度适配，手机与宽屏须同步验证。

## Elevation & Depth

当前页面无自定义阴影；设置分组以主题边框和明暗容器色区分，底部导航上方保留 FScaffold 默认分隔线。

## Shapes

按钮和设置分组沿用 ForUI 的 md 圆角及 RoundedSuperellipseBorder，不建立额外圆角体系。

## Components

使用 FScaffold、FHeader、FBottomNavigationBar/Item、FButton、FTileGroup、FTile。底部导航保留图标、标签和库默认选中状态；主按钮只切换当前页。设置中的 Telegram「未连接」、中转服务「未配置」为无 onPress 的状态行，不伪装为可用功能。当前没有输入框、影片卡片或播放器组件。

## Do's and Don'ts

- Do 使用当前 ForUI 主题、默认组件状态及 Lucide 图标，保留安全区域、字体缩放和滚动。
- Don't 添加虚构影片、连接成功状态或未实现功能的可点击入口。

实现：`app/lib/app/application.dart`、`app/lib/theme/theme.dart`、`app/lib/ui/features/` 与 `app/lib/ui/core/app_empty_state.dart`。架构见 [基础架构](docs/architecture.md)。
初始化版本的视觉证据：`.impeccable/review/phone-{library,history,settings}-light.png` 与 `phone-{library,history,settings}-dark-large.png` 六张模拟器截图；视觉约定在分层重构中保持一致。未验证真实设备。
