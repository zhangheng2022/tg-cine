---
version: 1
slug: "tg-cine-app-foundation"
primary_target: "app/lib/ui/features/home/views/home_view.dart"
related_targets: ["app/lib/ui/features/settings/views/settings_view.dart", "app/lib/ui/features/sources/views/sources_view.dart", "app/lib/ui/features/privacy/views/local_data_view.dart"]
---

# Flutter 应用基础界面

Mode: Operate. 用户授权执行阶段方案；本增量落实真实未连接状态、四项导航和本机主题设置，沿用已经确认的静态设计方向。

## Direction contract

THESIS: 片库、记录、来源和设置可找到；没有接入的媒体与服务如实显示不可用，不把静态示例导入真实片库。

OWN-WORLD: ForUI neutral touch、Inter 与中文平台回退、Lucide 图标、48dp 操作，明暗主题可在本机保存。

STORY: 空片库引导了解来源 → 来源说明账号权限 → 设置展示连接状态、外观和本机数据说明；返回保留导航上下文。

FIRST VIEWPORT: 手机采用标题、空状态与四项底部导航；中屏图标侧栏带可发现文字提示；宽屏文字侧栏与内容区。没有媒体时不绘制假海报或假续看。

FORM: 承接已确认的浏览片库结构，扩展现有空壳；不重新选择视觉世界。资料网格、详情预览、播放器随真实业务接入，不为它们制造空实现。

FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance.

## 验证边界

Flutter 组件测试与渲染截图覆盖手机、中屏、宽屏、明暗和字体缩放；运行时视觉证据与旧 HTML 设计稿分开记录。未验证真实 Telegram 登录、播放或公共服务；HTML/CSS detector 不用于 Flutter 验收。
