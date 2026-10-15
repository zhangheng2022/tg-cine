# 2026-10-15 拆仓与 v2 切换

已确认：Flutter 上提根目录；Worker 独立公开仓库并以首次提交初始化；Cloudflare Workers + Vite 工具链，Hono 处理 API；Cloudflare 技能全部迁移；不提供旧接口、旧协议或旧客户端兼容；旧 Worker 状态不保留。

## 目录与数据

Flutter 的六平台、lib、test、integration_test、tool、pubspec 和工程元数据位于根目录。工具按新的根定位，原根 `.cache/native/accounts/` 和系统应用数据目录保持原位。旧构建缓存存放在已忽略的 `.cache/pre-split-app/`，不作为新构建输入。

客户端删除旧中转凭据后独立激活 v2，保留 Telegram 会话、来源、片库和观看记录。服务端有删除旧 DO 类并创建新类的迁移配置；配置不是线上清理已执行的证据。

## 联调

客户端 CI 独立运行。服务端仓库执行 `npm run test:relay -- <客户端根目录>`，验证新版 Dart → workerd → TCP 的 1 MiB 字节顺序与关闭。服务端手工联调工作流要求输入客户端完整 commit SHA，避免隐式跟踪另一个仓库的主分支。

## 发布边界

拆仓初始阶段没有部署。2026-10-15 后续获得明确授权后，两个 PR 已合并，Worker 已执行旧状态销毁、密钥轮换及 v2 发布；[发布记录](https://github.com/zhangheng2022/tg-cine-worker/blob/master/docs/deployment.md)包含版本和验收范围。客户端真实服务代码及原生 TDLib 已通过 Telegram DC1–DC5 握手，Android/Windows 公开配置构建已生成。

本轮未安装覆盖用户设备，也未修改既有 Telegram 会话、媒体库或观看记录；真机升级后的数据恢复及完整影片播放尚未验收。v1 历史成功记录不算作 v2 线上验收。

Graphify 的旧图包含已迁移路径，已从活动位置移至忽略缓存；后续需要时分别明确更新两仓图谱。
