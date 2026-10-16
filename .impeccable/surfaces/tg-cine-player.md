---
version: 1
slug: "tg-cine-player"
primary_target: "lib/ui/features/player/views/player_view.dart"
related_targets: ["lib/ui/features/library/views/library_view.dart", "lib/app/application.dart"]
---

# Flutter 播放器

2026-10-16 日常使用增量：正式片库不显示开发工具说明。应用内全屏复用原生画面；控件显隐不重开媒体，系统返回或 Escape 先退出全屏，不改系统方向偏好。横竖屏按可用尺寸布局，安全区保留；大字体控制区可滚动，48dp 操作，暂停/缓冲/完成/失败时保持可见。原生设计数据矩阵与真实数据保护见 [日常使用闭环](../../docs/daily-use-stage.md)。

Mode: Operate. 沿用 ForUI neutral touch、Lucide 和中文文案；原生片库所选文件播放，保留 Windows 开发媒体入口；不导入静态示例片库。

首屏为视频画面、状态、进度和同一行的后退/播放暂停/前进；播放器主体最多 1080dp，操作区最多 420dp。手机保留同一操作顺序，宽屏及大字体按可用高度限制画面，让控制区可见，剩余内容可滚动。主控件最小 48dp。错误说明问题与恢复动作，不显示原始插件错误或私有 URL。

实测：320/800/1440 组件测试；390/1440 原生 Flutter 截图，明暗及两倍字体。布局截图使用明确标注的画面，真实首帧另通过 VideoController 的渲染完成事件验证。一次批量修正主按钮宽度、控制排布和大字体画面高度后确认，未使用 HTML 检测器。

2026-10-15 增量：片库详情可打开所选文件，标题显示原文件名，按账号和实际版本续播；保存失败使用 liveRegion 提示。窗口关闭、离页及后台暂停，账号或来源失效关闭媒体服务。Windows 合成协议数据已通过真实解码和进度恢复；移动真机、真实 Telegram 持续播放及完整影片仍未验收。
