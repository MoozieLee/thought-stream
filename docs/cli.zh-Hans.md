# CLI 指南

`thought` CLI 是 ThoughtStream 的查询驱动命令行接口。

适用场景：

- 快速本地查阅
- 脚本
- 自动化
- agent 工作流

## 构建

```bash
env HOME=$PWD/.home CLANG_MODULE_CACHE_PATH=$PWD/.build/ModuleCache swift build --product thought
```

## 常用命令

```bash
./.build/debug/thought list --json
./.build/debug/thought tail 100 --json
./.build/debug/thought search clustering --json
./.build/debug/thought today --json
./.build/debug/thought export --from 7d --json
./.build/debug/thought stats --json
./.build/debug/thought days --limit 14 --json
./.build/debug/thought add --tag work --pinned "important note"
./.build/debug/thought get <id>
./.build/debug/thought update <id> --content "updated text" --tag work
./.build/debug/thought delete <id>
```

## 命令分组

查询类：

- `list`
- `tail`
- `search`
- `today`
- `export`
- `stats`
- `days`
- `get`

写入和更新类：

- `add`
- `update`
- `delete`

## 写入操作

创建笔记：

```bash
./.build/debug/thought add "idea to revisit"
./.build/debug/thought add --tag work --tag cli --pinned "important note"
printf 'captured from stdin\n' | ./.build/debug/thought add --channel cli
```

更新笔记：

```bash
./.build/debug/thought update <id> --content "updated text"
./.build/debug/thought update <id> --tag work --tag review --pinned
./.build/debug/thought update <id> --clear-tags --unarchived --unpinned
```

删除笔记：

```bash
./.build/debug/thought delete <id>
```

## 归档筛选

大多数查询命令支持归档状态筛选：

```bash
./.build/debug/thought list --archived --json
./.build/debug/thought tail --unarchived --json
./.build/debug/thought search planning --archived --json
./.build/debug/thought today --unarchived --json
./.build/debug/thought days --archived --json
```

## Agent 工作流示例

导出最近通过 GUI 捕获的内容：

```bash
./.build/debug/thought export --from 7d --source human --channel gui --json
```

查询更早的数据切片：

```bash
./.build/debug/thought search "retrieval ranking" --offset 100 --limit 100 --json
```

查看今日捕获：

```bash
./.build/debug/thought today --source human --channel gui --json
```

查看按日汇总：

```bash
./.build/debug/thought days --from 30d --json
```

## 说明

- `thought add` 主要用于测试和自动化场景
- 主要捕获路径仍然是 GUI 覆盖层
- CLI 更适合进行较重的回顾和下游工作流处理
- `thought update` 支持 `--clear-tags`、`--archived|--unarchived` 和 `--pinned|--unpinned`
