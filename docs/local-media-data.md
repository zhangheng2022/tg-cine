# 本机媒体数据

更新：2026-10-14。原生存储基础已接入来源保存与历史分页片库；仅保存元数据，不下载媒体或新增播放器验收。导入流程见 [历史导入](library-import.md)。

## 结构与调用

`LocalMediaRepository` 是纯 Dart Domain 端口，`SqliteMediaRepository` 是 Data 实现。UI 继续通过 `SourcesViewModel → TelegramRepository` 保存来源；Windows 和 Android/iOS 原生适配器在 `getMe` 确认账号后恢复该账号的来源选择，关闭连接时释放数据库，再清零密钥并释放锁。

| 表 | 保存内容与约束 |
| --- | --- |
| `accounts` | Telegram 账号 ID、旧来源选择迁移标记；不存手机号或凭据 |
| `sources` | 账号、来源 ID、是否选中、最近获取的 Telegram 名称 |
| `messages` | 账号、来源、消息 ID、原说明、时间、当前实际版本 |
| `media_versions` | 稳定远程文件标识、文件名、大小、时长；同一消息可保留多个文件版本 |
| `import_checkpoints` | 下一页消息 ID、暂停/完成状态、修订号 |
| `playback_progress` | 按账号和实际版本保存毫秒位置；尚未接入播放器 |

外键包含账号作用域，关联删除不会影响其他来源或账号。只读分页默认 100 条、最多 200 条；原始片库按 50 条加载，参数化搜索文件名、原说明与来源名称，百分号按字面匹配；显示选中来源的当前版本，也可按消息读取历史版本。

## 去重、事务与迁移

- 版本键为 `[来源 ID, 消息 ID, remote_unique_id, 文件大小]` 的 JSON 序列化值，由账号隔离。重复扫描更新原始文件元数据；标识或大小变化保留另一版本。文件名、片名及 TDLib 临时 `file_id` 不参与身份判断；不同消息或来源不自动合并，不将远程标识视为内容哈希。
- 每批最多 200 条。消息、版本与检查点在同一事务提交，任何失败全部回滚；来源必须选中，暂停或过期修订号拒绝写入。分页器应把无视频页的游标也通过空批次提交，只有历史扫描结束才设置 `complete`。
- 取消选择保留本机内容与游标，停止后续批次并隐藏相应条目；重新选中可恢复。显式 `removeSource` 删除该来源消息、版本和进度，并保留仅含来源 ID 与新修订号的标记，防止旧批次复活内容；它不会调用 Telegram 删除接口。目前 UI 未提供这个清理动作。
- `PRAGMA user_version` 管理事务迁移：v1 建立账号、来源、消息、版本和检查点；v2 增加版本进度；v3 增加来源名称，原有消息、检查点与进度保持。更高版本、无法解密或迁移失败均报存储错误，不重建原文件。
- 旧 DPAPI/安全存储来源记录按账号迁移一次。读取成功后将选择与迁移标记一起提交；失败可重试，并发的新保存优先。旧记录保留，后续读取以数据库为准，不进行双写。

## 保护与平台

采用固定 `sqlite3 3.7.1` 的 Native Assets hook，配置 `source: sqlite3mc`；包内 hook 校验预编译产物 SHA-256，并为 Android/iOS 同步打包加密 SQLite。运行时必须检测到加密构建，禁止静默退回普通 SQLite。依赖能力与配置依据：[sqlite3 官方包说明](https://pub.dev/packages/sqlite3)、[构建 hook 文档](https://pub.dev/documentation/sqlite3/latest/topics/hook-topic.html)。原生加密组件还有各自许可证，发行前需核对 [SQLite3MultipleCiphers](https://github.com/utelle/SQLite3MultipleCiphers) 的许可材料。

媒体密钥独立随机生成 32 字节。Windows 使用现有 DPAPI、当前用户/SYSTEM ACL 与排他锁，数据库位于 Telegram 会话的同级 `<会话名>-media/media.db`；Android/iOS 使用 `applicationSupport/media/primary/media.db`，独立 Keychain/系统安全存储键 `tg-cine.media.primary.database-key.v1`。Android 禁用应用备份，iOS 两个数据目录均排除备份。已有文件但密钥缺失时保留文件并失败，不生成替代密钥。

数据库只存元数据和位置，不存 API Hash、服务令牌、登录输入、TDLib 会话或视频字节。当前不做导出、云同步或自动清理旧密钥；没有恢复密钥时无法读取已有库。

## 验证与后续

- 13 项数据库测试覆盖加密重开、错误密钥/损坏/更高版本保护、升级与失败回滚、旧选择迁移与并发保存、账号隔离、去重/版本进度、批次回滚、暂停/恢复、取消/删除后旧批次拒绝及分页边界；移动安全存储另验证独立媒体密钥及缺失密钥保护。
- 本机存储基础 159 项、历史导入增量后全量 199 项 Flutter 测试与静态分析通过。Android NE2210 真机、Windows 各通过一次相同存储集成验收，使用隔离测试目录与数据，结束清理测试密钥和文件；这是存储基础验收；本轮额外完成 Android/Windows 协议替身导入流程，Windows 真实授权来源累计保存 25 条元数据，移动真实 Telegram 导入与续看仍未完成。
- 普通客户端的 Android Debug APK、Windows Debug 与 Web 构建均通过，构建产物已恢复普通入口；没有将集成测试入口作为交付版本。
- CI 原生构建矩阵增加加密库测试；iOS 使用相同 Dart 实现、hook 配置及集成测试，但本机无法运行 Xcode，远程矩阵尚未运行。Web 仍保留未连接状态，未增加浏览器片库持久化。
- 当前 SQLite 操作在调用 isolate 中执行，每批有界；接入历史导入时先测量批次耗时，出现可见卡顿或规模增长再迁至后台 isolate。
- 历史分页、暂停/继续、搜索与源消息追溯已接入原始片库；增量新消息、资料识别与人工纠正仍待后续。当前只更新原始元数据，尚无人工纠正模型；添加时须独立保存并优先于导入结果。播放器进度接线另属下一阶段，不恢复播放稳定性排查。

本次使用源码与差异人工审查；当前 Code Review 工具只有 PR CI 诊断，没有本地差异审查接口。保留既有未提交改动，不提交代码或部署 Worker。
