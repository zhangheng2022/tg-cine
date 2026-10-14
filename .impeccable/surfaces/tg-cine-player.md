---
version: 1
slug: "tg-cine-player"
primary_target: "app/lib/ui/features/player/views/player_view.dart"
related_targets: ["app/lib/ui/features/library/views/library_view.dart", "app/lib/app/application.dart"]
---

# Flutter 播放器

Mode: Operate. 沿用 ForUI neutral touch、Lucide 和中文文案；真实 Windows 开发媒体入口，不导入静态示例片库。

首屏为视频画面、状态、进度和同一行的后退/播放暂停/前进；播放器主体最多 1080dp，操作区最多 420dp。手机保留同一操作顺序，宽屏及大字体按可用高度限制画面，让控制区可见，剩余内容可滚动。主控件最小 48dp。错误说明问题与恢复动作，不显示原始插件错误或私有 URL。

实测：320/800/1440 组件测试；390/1440 原生 Flutter 截图，明暗及两倍字体。布局截图使用明确标注的画面，真实首帧另通过 VideoController 的渲染完成事件验证。一次批量修正主按钮宽度、控制排布和大字体画面高度后确认，未使用 HTML 检测器。

边界：当前真实源依赖外部 Windows TDLib 开发工具；其他平台仅验证布局，未验证原生播放、完整影片或续看。
