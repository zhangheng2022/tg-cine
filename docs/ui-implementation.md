# Flutter UI 实施记录

更新日期：2026-10-12。本轮是既有 ForUI 界面的普通扩展：落实四项导航、真实空状态、本机外观设置和本机数据说明。阶段 3 仍为部分完成，尚未实现媒体网格、详情、选集或播放器。

## 已实现界面与路径

| 界面 | 当前行为 |
| --- | --- |
| 片库 | 显示「还没有影片」；「了解媒体来源」切换到来源。 |
| 观看记录 | 显示「从第一部影片开始」；「返回片库」切换到片库。 |
| 来源 | 显示「片库从来源开始」，说明只选择已有权限的频道或群；「查看连接状态」切换到设置。 |
| 设置 | Telegram 显示「未连接」，默认服务显示「暂不可用」；两项状态行没有登录或连接操作。外观提供跟随系统、浅色、深色。 |
| 本机数据说明 | 从设置推入独立页面，说明当前只保存外观、未接入登录/导入/播放，以及媒体权限和独立项目身份；返回后保留设置导航上下文。 |

四项固定目的地为片库、记录、来源、设置。当前没有已导入媒体，不绘制假海报、假续看或假连接成功状态。路由与空状态行为以 `home_view.dart`、各页 View 和 `app_zh.arb` 为准。

## 响应式布局

`HomeView` 使用可用窗口宽度判断布局，单位为 Flutter 逻辑像素；字号比例取 `MediaQuery.textScalerOf(context).scale(16) / 16`。

| 条件 | 导航与布局 |
| --- | --- |
| 宽度 < 600 | 四项底部导航，保留底部安全区域。 |
| 宽度 < 900 且字号比例 > 1.6 | 回退到底部导航，为放大文字保留内容宽度。 |
| 其余宽度 < 1024 | 88dp 图标侧栏；每项通过可见文字提示补充名称。 |
| 宽度 ≥ 1024 | 196dp 侧栏，显示图标和文字标签。 |

主体最大宽度 1080dp，居中靠上；主体额外横向内边距在底栏布局为 8dp、侧栏布局为 20dp，继续保留 `FScaffold` 默认内边距。设置和本机数据说明的阅读宽度最多 720dp。阈值来自 [`HomeView`](../app/lib/ui/features/home/views/home_view.dart)，不是设备或平台分类。

## 主题、滚动与操作

继续使用 [`theme.dart`](../app/lib/theme/theme.dart) 中的 `FTheme.neutral.light.touch` / `dark.touch`，ForUI 默认 Inter、平台中文字体回退和 Lucide 图标。颜色与排版从 `context.theme` 获取，中文文案从 `context.l10n` 获取；没有新增或获批的品牌 token 体系。

外观默认跟随系统。App 组合根注入设置仓库，ViewModel 依赖 Domain 端口，UI 不直接调用存储插件；`shared_preferences` 仅保存版本化的外观配置。保存成功后才切换选择；保存中禁用重复操作，失败显示重试提示并保留此前外观。读取失败保留原记录，重试成功前不写入。

共享空状态最大宽度 320dp，以可用高度为最小高度居中；上下留 32dp，图标 48dp，内容间隔为 24/12/28dp。空状态、设置和说明页各自纵向滚动，短屏或放大文字可以继续阅读。顶部沿用 `FHeader` 安全区域处理，侧栏使用 `SafeArea`；空状态主按钮、外观/重试按钮和侧栏操作最小高度 48dp，说明页返回控件为 48×48dp。

紧凑侧栏在 `FButton.icon` 外使用 `FTooltip`，提示文字来自对应导航标签，显示在图标右侧；保留 `semanticsLabel`、`semanticsTooltip`、选中态和点击回调。ForUI 0.27.4 自带焦点、鼠标悬停及触摸长按提示行为，键盘焦点和 Escape 处理沿用组件默认实现。本轮组件测试实测鼠标 hover、长按提示可见且不切换页面，再点击进入来源；Android 模拟器截图确认长按时「来源」可见。键盘焦点/快捷键和屏幕阅读器未单独实测。

## 验证证据与范围

运行结果沿用本轮主线记录；本实施记录未重复运行测试、构建或视觉审查。

| 证据 | 已验证范围 |
| --- | --- |
| Flutter 格式化、静态分析、测试 | 已通过；新增 tooltip 测试后由 31 项增至 32 项。布局测试覆盖 320×568、800×900、1440×900，明暗主题及 1/1.3/2 倍字号，共 18 个组合；另含空状态导航、外观持久化与失败重试。测试源码见 [`application_test.dart`](../app/test/app/application_test.dart)，执行状态见 [分阶段记录](development-plan.md)。 |
| Android 运行时截图 | Android 16 / SDK 36、Pixel_10 AVD、160dpi；12 张基线加 1 张 tooltip，共 13 张。覆盖 390×844 浅色 1.0、320×780 深色 1.3、800×900 深色 1.3、1440×900 浅色 1.0。由 ADB screencap/pull 获取，未合成系统栏；APK 和每张 PNG 的 SHA256 见 [capture-manifest.json](../.impeccable/review/foundation/capture-manifest.json)。这组截图没有覆盖全部 18 个测试组合。 |
| 独立视觉审查 | [review.md](../.impeccable/review/foundation/review.md) 的唯一 P2 为中屏图标导航缺少可见提示；加入 `FTooltip` 后，[verdict.md](../.impeccable/review/foundation/verdict.md) 记为 resolved / ship。最终确认仅复核该 P2 及其局部回归，未展开新一轮审查。 |
| 本机构建 | Android debug APK、Web、Windows release 已通过；构建成功不等于各平台运行时视觉和业务验收。 |

未验收：非 Android 平台的实际视觉、真实设备、iOS/macOS/Linux 本机构建与运行、远程 CI、真实 Telegram 登录/导入/播放。Worker 和 TDLib 的可行性与后续关卡仍见 [分阶段记录](development-plan.md)，不属于本 UI 完成结论。

截图和审查报告位于已忽略的 `.impeccable/review/`，仅为本机验收附件，不随仓库克隆提供；源码测试与本实施记录随仓库保留。

## 既有设计记录的漂移

本轮沿用既有 ForUI 视觉系统，没有重新选择视觉世界；根 `DESIGN.md` 和 `.impeccable/design.json` 保持原文件。它们仍包含三个初始化页面、无桌面断点、旧「中转服务 / 未配置」状态，sidecar 还保留手机优先叙述。这些是实施前已存在的描述漂移；当前四项导航、同步响应式布局和真实状态以源码及 [基础界面 brief](../.impeccable/surfaces/tg-cine-app-foundation.md) 为依据，本记录不将旧描述升级为新的系统规则。
