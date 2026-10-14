---
version: 1
slug: "tg-cine-ui-design"
primary_target: "docs/ui-design/index.html"
related_targets: ["docs/ui-design/screen.html", "docs/ui-design/design.css", "docs/ui-design/screens.js", "docs/ui-design/ui-spec.md"]
---

# TG Cine 静态 UI 设计

Mode: Operate. Scope: 手机与宽屏同时设计；用户明确选择静态高保真稿与规范，保留 Flutter、Worker 和当前运行时视觉记录。

## Direction contract

THESIS: 从已选来源找到媒体，明确选择版本或剧集，播放后下次本机续看；来源与识别状态始终可追溯。

OWN-WORLD: 继承 ForUI neutral light/dark touch 的黑白控件、Inter 与中文平台回退、Lucide 描边；原创虚构海报只承担媒体内容，不改变控件品牌。

STORY: 欢迎与媒体说明 → Telegram 登录设计 → 选择来源 → 渐进导入 → 片库 → 详情与选集 → 播放器 → 本机记录；待整理、隐私和故障恢复可从对应目的地找到。

FIRST VIEWPORT: 手机为标题与搜索、继续观看、本机标记、分类与来源、两列海报和四项底部导航。宽屏为侧栏、同一片库内容与选中影片详情预览；窄侧栏承接中等宽度。

FORM: 已选首页方案 B“浏览片库＋详情预览”。先前 wireframe 锁定结构，按代码表达的设计图绘制静态稿，不另开视觉世界或生成替代界面的北极星图片。HTML 仅为绘图与总览载体，不是 Flutter 实现。

SIGNATURE: 选中媒体时宽屏更新相邻详情，手机进入详情；选中、键盘焦点、正在播放分别表达。播放需明确操作，不凭选择自动开始。

FINISH: 完成 23 个页面／状态的手机与宽屏稿，独立审查及设计文档；影像注明来源。静态检查仅证明稿件的视觉与文案，不证明真实功能、原生辅助功能或部署可用性。

## Confirmed boundaries

- 本轮交付格式由用户选择：静态高保真设计稿，暂不修改 Flutter 界面。
- 中文、ForUI、手机和宽屏同步；公开用户、海外首发目标、取消邀请码；默认服务不需要填写地址或令牌。
- 影片、账号、导入计数和连接状态均为示例，画面明确标注。播放器控件无行为；不请求验证码、会话或服务凭据。
- 保留根 DESIGN.md 与旧页面 brief，它们仍描述初始化实现；不顺带修复已报告的 Impeccable 漂移。
- 历史方案中的“本轮不制作高保真”属于此前产品设计阶段；本任务新增静态视觉稿，不改变产品业务范围。
