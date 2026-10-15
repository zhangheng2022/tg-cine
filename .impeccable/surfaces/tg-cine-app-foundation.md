---
version: 1
slug: "tg-cine-app-foundation"
primary_target: "lib/ui/features/home/views/home_view.dart"
related_targets: ["lib/ui/features/settings/views/settings_view.dart", "lib/ui/features/sources/views/sources_view.dart", "lib/ui/features/privacy/views/local_data_view.dart"]
---

# Flutter 应用基础界面

Mode: Operate. 用户授权执行下一阶段，Android/iOS 同步实现、手机与宽屏同步适配；本增量落实原生 Debug 私有配置下的应用内登录与来源选择，沿用既有 ForUI 方向，已停止播放排查。

## Direction contract

THESIS: 片库、记录、来源和设置可找到；没有接入的媒体与服务如实显示不可用，不把静态示例导入真实片库。

OWN-WORLD: ForUI neutral touch、Inter 与中文平台回退、Lucide 图标、48dp 操作，明暗主题可在本机保存。

STORY: 空片库引导了解来源 → 未连接时按真实授权状态输入手机号、验证码、密码或邮箱 → 登录后搜索主列表/归档已加载来源、选择并保存本机记录；搜索保留选择，保存区固定在可滚动列表下方，退出需再次确认。设置展示真实连接状态、外观和本机数据说明；返回保留导航上下文。保存来源暂不导入影片。

FIRST VIEWPORT: 手机采用标题、空状态/登录表单/来源列表与四项底部导航；600dp 起为带可发现文字提示的图标侧栏，1024dp 起为文字侧栏。字体比例大于 1.6 且宽度小于 900dp 时回到底部导航。没有媒体时不绘制假海报或假续看。

FORM: ForUI neutral touch、中文标签和失败信息；登录表单最大 480dp、敏感字段遮蔽并在提交或步骤切换清空，来源用 FTextField/FCheckbox、outline 加载更多和 primary 保存。主要操作最小 48dp，保留安全区域、滚动、字体缩放和 busy 禁用态。不重新选择视觉世界；资料网格与详情预览待真实媒体业务接入，既有开发播放器与本次来源选择独立。

FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance.

## 验证边界

本轮 146 项 Flutter 测试、Android Debug APK 构建及 Windows 原生 Flutter 设计数据登录/来源集成流程通过。32 张 `.impeccable/review/telegram/{phone,wide}-{android,iOS}-{light,dark}-{1.0,2.0}-{login,sources}.png` 覆盖手机、宽屏、平台变体、明暗和字体缩放，逐张审查无材料缺陷；画面使用设计数据、由 Windows Flutter 渲染，不是 iOS 模拟器或真机截图。HTML/CSS detector 与 sidecar 的浏览器示意不用于 Flutter 验收。
Windows Data 真实 `getMe`、主列表/归档读取通过两次重开，不输出账号或来源标识；这不替代移动端验收。Android 真机设计数据 UI 流程与系统安全存储隔离记录读写/删除已通过；iOS 签名构建和真机未运行；Android TDLib 已交付，真机默认中转及完整手机号/验证码/两步验证授权通过；iOS 原生及真实移动来源恢复仍待验收。默认服务已开放，详见 docs/public-service.md 与 docs/mobile-native.md；本轮不新增真实播放验收结论。
