# 存储

默认情况下，ThoughtStream 将本地数据存储在：

```text
~/Library/Application Support/ThoughtStream
```

SQLite 数据库文件路径：

```text
~/Library/Application Support/ThoughtStream/thoughts.sqlite3
```

## 选择其他存储目录

如果你希望把数据库放到 iCloud Drive 之类的目录里，可以通过 GUI 或 CLI 切换存储位置。

### GUI

在菜单栏里的 ThoughtStream 菜单中可以使用：

- `Reveal Data Folder`
- `Change Storage Location...`
- `Reset Storage Location`

### CLI

```bash
# 查看当前存储位置
thought config show

# 设置自定义存储根目录
thought config set-root /path/to/your/folder
```

GUI 和 CLI 写入同一个配置文件，因此始终指向同一个存储位置。

## 配置文件

存储根目录持久化在一个 JSON 配置文件中：

```text
~/.config/thoughtstream/config.json
```

示例内容：

```json
{
  "storage_root": "/Users/you/iCloud Drive/ThoughtStream"
}
```

如果文件不存在，或 `storage_root` 字段为空，则使用默认位置。

## 生效优先级

ThoughtStream 会按下面的顺序决定存储根目录：

1. 调用方显式传入的 `baseDirectory`
2. `~/.config/thoughtstream/config.json` 中的 `storage_root`
3. `~/Library/Application Support/ThoughtStream`

不再使用环境变量或 UserDefaults——配置文件是唯一权威来源。

## 为什么用配置文件而非环境变量

环境变量容易导致 GUI 和 CLI 数据分裂：

- GUI 应用无法可靠读取 shell profile 中的环境变量
- 在 `.zshrc` 里设置不覆盖 bash/fish 用户
- 不同终端会话可能设了不同路径

配置文件是单一的、可预测的位置，GUI 和 CLI 一致读取。

## 清除本地数据

清除当前数据库内容而不删除整个文件：

```bash
./scripts/clear_db.sh
```

该脚本会从 `thoughts` 和 `thoughts_fts` 两张表中删除所有行，并重置 `thoughts` 表的 SQLite 自增计数器。
