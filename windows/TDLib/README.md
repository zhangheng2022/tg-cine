# Windows TDLib

公共接入从可执行文件旁加载 `tdjson.dll`。原生库不提交；使用 docs/native-tdlib.md 中已核验的 Windows 构建，`prepare_public_config.dart` 在本机校验哈希后安装到此目录，CMake 再次校验并打包。

其他工具链产物必须重新核验提交来源、导出、依赖及许可证，并同步更新校验值。没有此产物的模板构建可以通过，但真实公共 Telegram 接入会明确失败。
