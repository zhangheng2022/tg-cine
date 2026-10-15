# 2026-10-15 拆仓与 v2 切换

已确认：Flutter 上提根目录；Worker 独立公开仓库并以首次提交初始化；Cloudflare Workers + Vite 工具链，Hono 处理 API；Cloudflare 技能全部迁移；不提供旧接口、旧协议或旧客户端兼容；旧 Worker 状态不保留。

## 目录与数据

Flutter 的六平台、lib、test、integration_test、tool、pubspec 和工程元数据位于根目录。工具按新的根定位，原根 `.cache/native/accounts/` 和系统应用数据目录保持原位。旧构建缓存存放在已忽略的 `.cache/pre-split-app/`，不作为新构建输入。

客户端删除旧中转凭据后独立激活 v2，保留 Telegram 会话、来源、片库和观看记录。服务端有删除旧 DO 类并创建新类的迁移配置；配置不是线上清理已执行的证据。

## 联调

客户端 CI 独立运行。服务端仓库执行 `npm run test:relay -- <客户端根目录>`，验证新版 Dart → workerd → TCP 的 1 MiB 字节顺序与关闭。服务端手工联调工作流要求输入客户端完整 commit SHA，避免隐式跟踪另一个仓库的主分支。

## 发布边界

本轮不部署、不清理远程状态、不安装覆盖用户设备。公开仓库与本地测试完成后，仍须授权执行 Worker 状态销毁与发布，并使用新版客户端验证凭据、Telegram 连接和数据恢复。v1 历史成功记录不算作 v2 线上验收。

Graphify 的旧图包含已迁移路径，已从活动位置移至忽略缓存；后续需要时分别明确更新两仓图谱。
