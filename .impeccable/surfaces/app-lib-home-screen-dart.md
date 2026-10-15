---
version: 1
slug: "app-lib-home-screen-dart"
primary_target: "lib/ui/features/home/views/home_view.dart"
related_targets: ["lib/app/application.dart", "lib/ui/core/app_empty_state.dart"]
---

# Flutter 手机端初始化

Mode: Operate. Scope: 六个平台的 Flutter 官方模板，手机端界面优先；不实现账号登录、视频播放或中转。

## Direction contract

THESIS: 忠实使用用户指定的 ForUI 组件，真实空状态引导到设置，不添加假影片或假连接。

OWN-WORLD: ForUI neutral touch 默认主题、Lucide 图标、系统明暗模式、中文文案。

STORY: 用户看到片库为空，通过主按钮或底部导航查看设置，也能查看空的观看记录。

FIRST VIEWPORT: 顶部 TG Cine 标题，中间影片图标、空状态说明与前往设置按钮，底部片库、记录、设置三项导航。

FORM: 用户指定的 ForUI 默认组件体系；本次为工程初始化，不另行发明视觉世界。

FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance

Constraints: 保留系统安全区域与字体缩放；小屏内容可滚动；未接入的连接状态不可交互。
