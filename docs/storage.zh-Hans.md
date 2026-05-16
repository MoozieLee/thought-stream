# 存储

默认情况下，ThoughtStream 将本地数据存储在：

```text
~/Library/Application Support/ThoughtStream
```

SQLite 数据库文件路径：

```text
~/Library/Application Support/ThoughtStream/thoughts.sqlite3
```

## 开发环境覆盖

在开发或自动化运行时，可以覆盖存储根目录：

```bash
export THOUGHT_STREAM_HOME="$PWD/.thought-stream"
```

## 为什么需要这个

这在以下场景中很有用：

- 隔离测试数据
- 运行可重复的本地实验
- 避免开发笔记与日常数据混合

## 清除本地数据

清除当前数据库内容而不删除整个文件：

```bash
./scripts/clear_db.sh
```

该脚本会从 `thoughts` 和 `thoughts_fts` 两张表中删除所有行，并重置 `thoughts` 表的 SQLite 自增计数器。
