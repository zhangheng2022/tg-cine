---
name: TG Cine
description: Flutter 响应式应用、默认服务、登录、来源与渐进片库的 ForUI 默认视觉记录
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

沿用 ForUI 0.27.4 的 neutral light/dark touch 默认主题；本次未另行建立品牌视觉世界。产品目标保留 Android、iOS、Web、Windows、macOS、Linux 六个平台，手机与宽屏界面须同时适配，中文（zh_CN）界面，图标使用 ForUI Lucide。外观可选跟随系统、浅色或深色，并保存在本机。
片库、记录、来源和设置组成四项导航；原生客户端通过内置默认服务接入应用内登录、来源选择与原文件片库。默认服务状态与 Telegram 登录状态分开显示；未具备项目应用标识或对应 TDLib 的构建保持不可用，Windows Debug 可保留原本机数据目录并改用独立设备凭据。观看记录、电影与电视剧资料、片库播放和续看尚未接线。Windows 开发播放器沿用相同视觉系统；当前业务与平台验收边界以 PRODUCT.md 为准，线上默认服务结果见 docs/public-service.md。

## Colors

Primary 为主题的黑白主操作对比色；Neutral 用于页面、文字、说明与边框。前置 token 记录实际值；浅色设置容器与页面同色，深色设置容器使用 dark-card。运行时始终通过 `context.theme.colors` 获取颜色。

## Typography

使用 ForUI 默认 Inter，中文由平台字体回退显示，保留系统字体缩放。空状态标题为 `display.xl2`、说明为 `body.md`；根标题沿用 FHeader 默认粗体，登录、来源和外观分节标题使用 `body.lg` 与 600 字重。按钮沿用 `body.sm`（16sp、500、行高 1），底部标签沿用 `body.xs3`（10sp、行高 1.5）。前置 px 仅是可移植记录，Flutter 字号按逻辑尺寸及字体缩放生效。

## Layout

FScaffold 保留默认横向内边距；FHeader 处理顶部安全区域，底部导航显式启用 `safeAreaBottom`。布局依据可用窗口宽度：小于 600dp 使用底部导航；600–1023dp 使用 88dp 图标侧栏与文字提示；1024dp 起使用 196dp 文字侧栏。字号比例大于 1.6 且窗口小于 900dp 时退回底部导航。主体居中、最大宽度 1080dp，额外横向内边距在底部导航布局为 8dp、侧栏布局为 20dp。
主体各页独立滚动；空状态以可用高度为最小高度居中，宽度最多 320dp、上下内边距 32dp，空间不足时可纵向滚动。空状态图标 48dp；顺序间隔为 24、12、28dp；主按钮约束最小高度 48dp。登录表单最大宽度 480dp、上下内边距 32dp；设置最大宽度 720dp、顶部留 16dp。来源列表独立滚动，已选数量和保存操作固定在其下方，通过 Wrap 适应窄屏与大字号。

片库按主体可用宽度组织布局：达到 860dp 且字体倍率小于 1.6 时，文件列表与详情以 6:5 并排，中间留 24dp；否则点击文件进入独立详情页。搜索与入口操作位于列表上方，操作用 Wrap 换行；来源进度、错误与重试、文件和加载更多处于同一可滚动列表，避免小屏大字号挤压。详情独立滚动，返回操作为 48×48dp。

Windows 开发播放器主体最多 1080dp，黑色舞台保持视频比例；按窗口高度和字号约束舞台高度，控制区最多 420dp，后退/播放暂停/前进同排，主操作最小 48dp。

## Elevation & Depth

当前页面无自定义阴影；设置分组以主题边框和明暗容器色区分，底部导航上方保留 FScaffold 默认分隔线。

## Shapes

按钮、输入框和设置分组沿用 ForUI 主题形状；按钮和分组保留 md 圆角及 RoundedSuperellipseBorder，不建立额外圆角体系。

## Components

使用 FScaffold、FHeader、FBottomNavigationBar/Item、FSidebar/Item、FTooltip、FButton、FTileGroup、FTile、FTextField 和 FCheckbox，保留库默认状态与主题。四项导航固定为片库、记录、来源、设置；窄侧栏同时提供语义标签与文字提示。外观按钮用 primary 表示当前选择、outline 表示其他选择。

### 登录与来源

登录输入框随授权步骤切换标签和键盘类型；验证码、邮箱验证码和密码遮蔽显示，禁用自动纠错、建议与个性化输入学习。提交即清空输入，步骤切换销毁原输入控件；忙碌状态禁用提交与相关操作，失败信息使用中文并通过 liveRegion 宣告。尚不支持的步骤显示真实说明，不伪造成功。
来源页使用 FTextField 搜索已加载条目，FCheckbox 显示选择，长名称最多两行并省略；搜索不清除已选项目。加载更多使用 outline，保存使用 primary，退出使用 ghost，并提供「确认退出登录」与「保持登录」。主要提交、选择和保存操作保留 48dp 最小高度。
保存来源后可手动开始历史导入，按批生成原文件片库；当前没有海报影片卡片。

### 默认服务与连接状态

设置页沿用两行 FTile：Telegram 行独立显示账号是否已登录，有接入 ViewModel 时进入来源页；默认服务行只展示状态，不提供点击入口。服务就绪显示「已连接」，默认服务初始化时显示「连接中」，未配置或连接失败时显示「暂不可用」。服务已连接不等于 Telegram 已登录。公共接入说明明确自动连接、会话与片库保存在本机，以及无需填写服务地址或访问令牌；现有开发接入继续显示对应说明。

来源页服务访问失效时显示明确中文错误并由用户重新连接，不自动重新注册安装；重新启用保留本机 Telegram 会话与片库。额度或连接数不足时提示暂停导入并稍后重试，错误沿用 liveRegion。说明与失败信息随字体缩放换行、页面可滚动，连接操作保留 48dp 最小高度。访问凭据、刷新凭据与开发令牌不出现在页面、截图或公开构建的服务配置表单中。

### 渐进片库与文件详情

片库使用 FTextField 搜索原文件名、原说明或来源名称；搜索跨导航保留，切换账号或来源选择后清空旧显示。已有文件时默认收起来源进度，空库时展开。来源显示已保存数量与待开始、整理中、暂停或完成状态；开始与继续用 primary，暂停与重试用 outline，导入状态与失败用 liveRegion 宣告。应用进入后台暂停，回到前台须手动继续；完成只表示该次历史扫描结束，不表示持续同步。

原文件行使用 ghost FButton，原文件名最多两行，来源一行省略，大小与时长用 Wrap；未知时长明确显示未知。详情保留完整可选择文件名、来源、大小、时长和原说明，复制源消息链接用 outline，成功或失败提供中文反馈。主要导入、暂停、重试、加载和复制操作最小高度 48dp。文件行不提供播放按钮；没有海报时保留文件列表，不以设计数据代替真实媒体。

### 开发播放器

FSlider 显示时间与可访问进度，手势结束才发定位命令；加载、缓冲、结束和错误用真实后端状态显示。开发媒体与来源选择独立；现有运行时范围和真实定位检查见 [播放器接入记录](docs/flutter-player.md)。

## Do's and Don'ts

- Do 使用当前 ForUI 主题、默认组件状态及 Lucide 图标，保留安全区域、字体缩放和滚动。
- Do 按可用窗口宽度适配导航、表单和固定保存区，同时验证手机、宽屏、明暗主题与两倍字体。
- Do 清空已提交或已切换步骤的敏感输入，搜索时保留来源选择，退出登录再次确认。
- Don't 添加虚构影片、连接成功状态或未实现功能的可点击入口。
- Don't 将 Windows 上的平台变体渲染、共用代码或打包入口记录为 Android/iOS 真机验收。

实现：`app/lib/app/application.dart`、`app/lib/theme/theme.dart`、`app/lib/ui/features/` 与 `app/lib/ui/core/app_empty_state.dart`。架构见 [基础架构](docs/architecture.md)。
初始化版本的视觉证据保留于 `.impeccable/review/phone-{library,history,settings}-light.png` 与 `phone-{library,history,settings}-dark-large.png`。本轮登录/来源证据为 `.impeccable/review/telegram/{phone,wide}-{android,iOS}-{light,dark}-{1.0,2.0}-{login,sources}.png` 共 32 张；由 Windows 原生 Flutter 渲染平台变体，使用设计数据，无真实账号或媒体。逐张视觉审查未发现材料缺陷；这些画面不是 iOS 模拟器或真机截图。Android 真机设计数据 UI 流程与系统安全存储隔离记录读写/删除已通过，iOS 签名构建和真机未运行，移动端 TDLib 原生库尚未生成，不计为真实移动 Telegram 接入完成。

渐进片库证据为 `.impeccable/review/library/{phone,wide}-{android,iOS}-{light,dark}-{1.0,2.0}-{library,details,failure}.png` 共 48 张 Windows 原生 Flutter 设计数据截图。独立 Impeccable 复核结论为 ship：320×568、两倍字体的失败态已将错误与重试纳入同一列表，详情返回为 48×48dp；48 张有效截图中的 24 对 Android/iOS 平台变体哈希一致，不能据此认定移动平台实际渲染相同。全量 199 项 Flutter 测试、静态分析与普通 Android Debug 构建通过。Android NE2210 真机及 Windows 的协议替身 → 真实加密 SQLite → Flutter 导入、去重与重开恢复通过；Windows 真实授权来源两次独立进程批次累计保存 25 个元数据条目，游标继续推进，历史未结束。上述数据接线与截图不替代真实移动 Telegram 导入；iOS Xcode 构建和真机、远程 CI 未运行。本轮不下载视频，不新增播放验收结论；详见 [历史导入记录](docs/library-import.md)。

默认服务增量证据为 `.impeccable/review/default-service/{phone,wide}-{android,iOS}-{light,dark}-{1.0,2.0}-{connected,unavailable,renew}.png` 共 48 张 Windows 原生 Flutter 设计数据截图。独立复审未发现材料布局问题；24 对平台变体哈希一致，合并当前文档后视觉结论为 ship，无需再截图。全量 222 项 Flutter、58 项 Worker 测试通过；Android NE2210 真机与 Windows 的协议替身已通过真实系统安全存储注册、重开刷新及撤销。截图和存储验证不代表真实移动 Telegram 接入，移动 TDLib、iOS Xcode 与真机、远程 CI 及播放仍未验收；线上切换结果以 [公共服务记录](docs/public-service.md) 为准。
