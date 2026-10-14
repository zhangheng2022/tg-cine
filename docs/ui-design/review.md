# TG Cine 静态 UI 设计审查记录

日期：2026-10-12。范围：静态高保真稿与设计规范；最终静态修复复审已归档，disposition 为 ship，范围见下文。

## 文档核对结论

Impeccable Documenter 在独立子代理中执行，读取 `reference/degraded/documenter.md` 与 `reference/document.md`，按普通扩展流程核对已有 ForUI neutral 世界。本轮没有新建或替换品牌视觉系统。文档核对只写入本文件及 `ui-spec.md` 的必要边界说明。

静态稿继续采用黑白控件、Inter 与中文平台回退、Lucide 风格描边、边框与底色分层；电影海报承担内容色彩。手机为片库与独立详情，宽屏为侧栏、海报网格和相邻详情预览，符合已选方案 B。选择、播放与本机续看均在静态文案中区分。

`DESIGN.md` 记录实际存在的三页 Flutter 初始化界面；`ui-spec.md` 描述静态稿及后续实现要求。浅色说明色 `#666666`、14sp 正文目标、四目的地导航、影片组件和响应式断点只属于本轮设计交付，没有被写成当前原生运行时事实。

## 证据与覆盖

| 证据 | 核对结果及范围 |
| --- | --- |
| `PRODUCT.md`、`DESIGN.md`、`.impeccable/design.json` | 对照产品约束、当前三页 shell、ForUI neutral 明暗主题；保留原文件 |
| `.impeccable/surfaces/tg-cine-ui-design.md` | 对照 THESIS、OWN-WORLD、STORY、FIRST VIEWPORT、FORM 及静态交付边界 |
| `design.css` | 核对实际明暗颜色、14px 正文基准、标题层级、圆角、48px 主操作范围、600／1024px 布局转换与大字覆盖规则 |
| `screens.js`、`screen.html` | 核对 23 个页面／状态、四目的地导航、示例数据标记、版本数量与无业务事件的控件表达 |
| `index.html` 与 `exports/` | 23 张手机浅色主稿、23 张宽屏浅色主稿、15 张补充稿，共 61 张 JPG；总览中的 15 个补充图直接链接均指向现有文件 |
| 本地 JPG 抽样 | Documenter 查看手机浅色片库、宽屏深色片库、320 小屏深色大字设置三张导出；未运行浏览器 |
| `render-check.json` 的 `checks` | 50 条已有记录：23 页在 390×844 和 1440×900 浅色尺寸的 46 条，加 320×568 深色大字片库／设置、800×900 深色大字片库、1280×720 深色大字片库的 4 条；均记录字体 loaded、空 overflow 与空 shortActions |
| `render-check.json` 的 `reviewChecks` | 4 条已有重点复查：320×568 片库、1280×720 片库、390×844 电影详情、390×844 播放器；记录 viewportOverflow 为 false、smallIcons 为 0，并对续看缩略图及侧栏标签提供几何值 |

这些 JSON 字段是静态检测记录，Documenter 未重新运行检测，也未将字段扩大解释为全部可点击元素、所有主题组合或原生辅助功能已合格。导出图总数、视觉评审数量和尺寸检测记录数分别计数。

## 独立视觉审查状态

1. 完整独立评审逐张查看 61 张导出图，要求修复五项问题：素材裁切、48×48 操作范围、侧栏大字标签、可用版本数量、补充图直接链接。
2. 第一批修复后，独立复审将这五项标为 resolved；版本数量统一为 2，15 张补充图提供直接链接。同时发现手机播放器扩大控件后，全屏控件孤立到第二行的回归，disposition 为 fix。
3. 第二批仅调整手机播放器控件分组并重新导出：第一行播放／暂停、快退、音量、全屏，图标均为 48×48；第二行字幕与选集，390px 稿中各为 171×48。宽屏布局保持原样。
4. 最终独立复审确认 `phone-player-light.jpg` 的两行分组与 48×48 范围，播放器回归为 resolved；原五项仍为 resolved，remaining 为 clear，未发现本批回归，disposition 为 ship。

最终 reviewer 明确限定：没有重新全量审查，没有运行 Flutter 或真机；本次 ship 仅覆盖已评分的静态修复。初始 61 张完整视觉评审与两次修复复审共同构成本轮记录，不等同于全平台、所有界面或整套业务无缺陷验收。

## 已有漂移与未纳入系统的差异

- `.impeccable/design.json` 的 narrative 仍含“手机端界面优先”，旧 `.impeccable/surfaces/app-lib-home-screen-dart.md` 仍采用初始化阶段的手机优先范围。当前 `PRODUCT.md`、根 `DESIGN.md` 与本轮 direction contract 已写明手机和宽屏同步。这是既有文档漂移，普通扩展不顺带修复。
- 静态稿与原生 ForUI 当前 token 的说明色、字号、布局和组件差异被限定为设计目标，不重新生成根 `DESIGN.md` 或 sidecar，不将静态 CSS 数值升级为原生规范。
- 静态大字示意不是 Flutter `TextScaler`；中屏窄侧栏为图标表达，按内容约束关闭预览、读屏名称、可见焦点与键盘操作仍是实施要求。
- 播放器画面来自竖向虚构海报的静态裁片，实际视频必须保留原始画幅；此占位方式不成为播放器的媒体裁切规则。
- 150–250ms 动效、业务交互、真实来源资料、隐私文本与 URL 均为后续实现或运营要求，不能从静态画面推断已完成。

## 验证与写入边界

保留 `app/`、`worker/`、`AGENTS.md`、`PRODUCT.md`、根 `DESIGN.md`、`.impeccable/design.json` 和两个 surface brief；不增加重复视觉系统文档，不提交，不部署。现有用户改动保持原样。

本轮未验证 Flutter 运行、组件交互、真机、六个平台原生行为、读屏、键盘导航、系统返回、横屏、网络可达、Telegram 登录、媒体解码、真实中转或 App Store 审核。Worker 当前入口仍返回 `501 / TUNNEL_NOT_IMPLEMENTED`。这些边界不因静态视觉审查而改变。
