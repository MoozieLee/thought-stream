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
./.build/debug/thought config show
./.build/debug/thought config set-root /path/to/folder
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

配置类：

- `config`

## 命令说明

`list`

- 通用查询命令
- 支持 `--limit`、`--offset`、`--from`、`--to`、`--source`、`--channel`、`--archived`、`--unarchived`、`--desc`、`--json`

`tail`

- 查看最近的笔记
- 既可以写 `tail 100`，也可以写 `tail --limit 100`
- 支持归档过滤以及来源、渠道过滤

`search`

- 全文搜索
- 查询词可以直接位置传参，例如 `thought search onboarding`
- 支持 `--limit` 和 `--offset` 分页

`today`

- 只返回当前自然日内的结果
- 支持 `--limit`、`--offset`、归档过滤和来源、渠道过滤

`export`

- 过滤模型与 `list` 相同
- 始终输出 JSON

`stats`

- 返回总数、活跃天数、第一条和最后一条时间

`days`

- 返回按日聚合的汇总，而不是单条笔记

`add`

- 新建一条笔记
- 如果存在 stdin，则优先从 stdin 读取；否则使用位置参数文本
- 支持 `--tag`、`--source`、`--channel`、`--archived`、`--pinned`

`update`

- 按 id 更新已有笔记
- 支持 `--content`、重复 `--tag`、`--clear-tags`、`--archived|--unarchived`、`--pinned|--unpinned`

`delete`

- 按 id 删除笔记

`get`

- 按 id 获取单条笔记
- 支持 `--json`

`config show`

- 输出当前实际生效的存储根目录，以及它来自配置文件还是默认路径

`config set-root`

- 修改存储根目录，并在需要时迁移数据库
- 当目标目录已存在数据库时，支持 `--overwrite`、`--merge`、`--keep-destination`

## 日期格式

`list`、`search`、`export`、`days` 这类支持时间过滤的命令接受：

- 绝对日期，例如 `2026-05-12`
- 本地时间戳，例如 `2026-05-12 09:30`
- ISO 时间，例如 `2026-05-12T09:30:00+08:00`
- 相对时长，例如 `30m`、`24h`、`7d`

示例：

```bash
thought list --from 7d
thought search planning --from 2026-05-01 --to 2026-05-08
thought export --from "2026-05-12 09:30" --json
```

## 归档与过滤语义

大多数查询命令支持：

- `--archived` 只看已归档
- `--unarchived` 只看未归档
- `--source <值>`
- `--channel <值>`

示例：

```bash
thought list --archived --json
thought tail --unarchived --json
thought search planning --source human --channel gui --json
thought today --source human --channel gui --json
thought days --archived --json
```

## 配置存储位置

CLI 和 GUI 应用读写同一个配置文件，始终指向相同的存储位置。

```bash
# 查看当前存储根目录
thought config show

# 设置存储根目录（自动迁移数据）
thought config set-root /path/to/folder

# 如果目标目录已有数据库，可以选择覆盖、合并，或保留目标目录
thought config set-root /path/to/folder --overwrite
thought config set-root /path/to/folder --merge
thought config set-root /path/to/folder --keep-destination
```

冲突处理语义：

- `--overwrite`：用当前数据库覆盖目标数据库
- `--merge`：把当前数据库内容合并进目标数据库
- `--keep-destination`：保留目标数据库，丢弃当前本地数据库

变更存储根目录时，现有数据库以及对应的 `-wal`、`-shm` 文件会一起迁移或清理。

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
- 如果 `PATH` 里没有 `thought`，可以直接使用 `./.build/debug/thought`，或者重新安装应用
