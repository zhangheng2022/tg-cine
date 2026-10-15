---
version: 1
slug: "tg-cine-library"
primary_target: "app/lib/ui/features/library/views/library_view.dart"
related_targets: ["app/lib/ui/features/library/views/media_details_view.dart"]
---

# 渐进片库与文件详情

Mode: Operate. 沿用已确认的 ForUI neutral touch、Inter/中文回退、Lucide、明暗主题及既有四项响应式导航，不另建视觉世界。本轮为原生 Debug 授权来源的历史分页、暂停/恢复、原始条目搜索与源消息追溯；iOS/Android 共用逻辑，不恢复播放排查。

## Direction contract

THESIS: 已保存的真实文件可找到；每批保存后即可浏览，用户知道哪些来源仍在整理，并可暂停后继续。

OWN-WORLD: ForUI 默认组件与主题、48dp 操作、中文标签、原文件信息优先；没有海报时使用文件列表，不伪造海报或可播放状态。

STORY: 保存来源 → 在片库开始分批导入 → 已保存条目立即可见 → 搜索文件名、说明或来源 → 选择文件查看大小、已知时长和原说明 → 复制源消息链接回 Telegram 追溯。后台暂停，前台由用户继续；切换账号清空当前显示。既有开发播放器与本条流程独立。

FIRST VIEWPORT: 有内容时首先展示搜索、导入来源入口、管理来源和真实文件列表；空库则展开来源进度与开始操作。来源控制与文件处于同一条可滚动列表，避免小屏大字号的嵌套滚动陷阱。

FORM: 文件行显示原文件名、来源、大小和已知时长；长名称两行省略，详情可读完整名称。宽度达到 860dp 且字号比例小于 1.6 时并排预览，其他窗口打开独立详情页。搜索跨导航保留；加载、失败、无结果、暂停、完成各有中文反馈。导入按保存条目计数，不使用虚构百分比；本轮没有影片播放按钮、影视资料识别或跨设备同步。

FINISH: Flutter 组件矩阵、原生渲染截图、独立 Impeccable 审查与文档记录；不以浏览器 detector 判断 Flutter 布局，不把 Windows 平台变体称为移动真机截图。截图仅使用标注的设计数据。

## 验收边界

原文件片库、历史分页、暂停/继续、搜索、详情与源消息链接已接线；观看记录、电影与电视剧资料、片库播放和续看尚未接线。完成态仅表示该次历史扫描结束，尚不自动同步新消息。

全量 199 项 Flutter 测试、静态分析及普通 Android Debug 构建通过。Android NE2210 真机与 Windows 的协议替身 → 真实加密 SQLite → Flutter 导入、去重及重开恢复通过，不能代替真实移动 Telegram 导入。真实 Windows 授权来源两次独立进程批次累计保存 25 个元数据条目，检查点继续推进，历史未结束；输出只保留数量，不捕获私有片库画面，不下载视频。

`.impeccable/review/library/` 的 48 张 Windows 原生 Flutter 设计数据截图覆盖 Android/iOS 平台变体、手机/宽屏、明暗、1.0/2.0 字体和片库/详情/失败。独立 Impeccable 复核为 ship：320×568 两倍字体失败态的错误与重试已置于同一列表，详情返回为 48×48dp；所有截图有效，24 对平台变体哈希一致。这些不是移动截图，不能据此认定 Android/iOS 实际渲染相同。

iOS 本机没有 Xcode，未完成构建、签名或真机验收；移动 TDLib 原生库尚未交付，真实移动 Telegram 导入未验收，远程 CI 未运行。本轮不恢复播放排查。
