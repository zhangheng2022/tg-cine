---
version: 1
slug: tg-cine-default-service
primary_target: app/lib/ui/features/settings/views/settings_view.dart
related_targets: [app/lib/ui/features/sources/views/sources_view.dart]
---

# 默认服务接入状态

Mode: Operate。继承现有 ForUI neutral touch、中文、Lucide、明暗主题和手机/宽屏导航，不另建视觉世界。

THESIS: 默认服务的连接与 Telegram 登录分开表达；用户无需填写地址或中转令牌。

STORY: 应用自动获取公开配置及设备访问凭据 → 默认服务已连接 → 用户登录自己的 Telegram → 原来源/片库流程。公共构建未配置项目 API 标识或未打包 TDLib 时保持不可用，不虚构连接。凭据被拒绝后显示明确错误，由用户点「重新连接」重新启用；服务额度或并发不足给出稍后重试提示。

FORM: 保留设置页两行 FTile 连接信息和可滚动说明。默认服务只展示连接中、已连接或暂不可用，不提供点击入口；Telegram 单独显示登录状态，有接入 ViewModel 时进入来源页。服务已连接不等于账号已登录。大字号的说明与失败信息换行、页面滚动，错误通过 liveRegion 宣告，操作保留 48dp。登录表单沿用 480dp 限宽，设置沿用 720dp 限宽。不展示凭据，不增加服务地址或共享令牌输入。

FINISH: 视觉 ship。`.impeccable/review/default-service/{phone,wide}-{android,iOS}-{light,dark}-{1.0,2.0}-{connected,unavailable,renew}.png` 的 48 张原生 Flutter 设计数据截图覆盖手机/宽屏、明暗、字体缩放和连接成功/不可用/访问失效重新启用。独立复审未发现材料布局问题；24 对 Android/iOS 平台变体哈希一致，持久文档合并后无需再截图。不捕获用户会话、凭据或真实片库；画面由 Windows Flutter 渲染，不算 iOS/Android 真机视觉证据。全量 222 项 Flutter、58 项 Worker 测试通过；Android NE2210 真机与 Windows 的协议替身通过真实系统安全存储注册、重开刷新及撤销。Android TDLib 已交付，真机默认中转握手与手机号页通过；完整移动账号授权、iOS 原生与真机、远程 CI 及播放尚未验收，详见 docs/mobile-native.md。线上启用结果以 `docs/public-service.md` 为准。
