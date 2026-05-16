<p align="center">
  <strong>🇨🇳 简体中文</strong>
  &nbsp;&bull;&nbsp;
  <a href="./README.md">🇬🇧 English</a>
</p>

# ThoughtStream

ThoughtStream 是一个本地优先的 macOS 想法捕获工具，附带一个以查询为中心的 CLI，用于后续检索。

它的设计围绕一个核心约束：

- 捕获必须保持快速
- 覆盖层内的检索必须保持轻量
- 更重的回顾工作应在后续通过 CLI 或 agent 工作流完成

## 包含什么

- **`ThoughtStreamApp`**
  - 一个 Spotlight 风格的 macOS 覆盖层
  - 全局快捷键：`Shift + Command + Space`
  - 快速捕获，轻量斜杠命令，结果复用
- **`thought`**
  - 用于查询、导出、更新和删除想法的 CLI
  - 面向脚本、自动化和 agent 工作流

## 架构概览

```
Package.swift
├── ThoughtStreamCore  (库)   — 数据模型 + SQLite 存储 + 查询引擎
├── ThoughtStreamApp  (可执行) — 原生 macOS 面板应用
└── thought            (可执行) — CLI 查询工具
```

三个 target 共享 `ThoughtStreamCore` 作为底层库，实现数据模型和持久化逻辑的复用。

## 快速开始

### 一行命令安装（需 macOS 13+）

```bash
curl -fsSL https://raw.githubusercontent.com/liyipeng/thought-stream/main/scripts/install.sh | sh
```

该命令从 GitHub Releases 下载最新 DMG，将应用安装到 `/Applications`，同时创建 `thought` CLI 软链接。

### 从源码构建

```bash
# 构建 GUI 应用
env HOME=$PWD/.home CLANG_MODULE_CACHE_PATH=$PWD/.build/ModuleCache swift build --product ThoughtStreamApp

# 构建 CLI
env HOME=$PWD/.home CLANG_MODULE_CACHE_PATH=$PWD/.build/ModuleCache swift build --product thought
```

### 安装并启动应用

```bash
./scripts/install_app.sh
```

或者直接运行调试版本：

```bash
./.build/debug/ThoughtStreamApp
```

### 首次启动

如果使用本地构建（未签名或 ad hoc 构建），macOS Gatekeeper 可能会阻止首次启动。这种情况下：

1. 先将 `ThoughtStream.app` 拖到 `/Applications`
2. 从 Finder 中右键 `ThoughtStream.app` 选择「打开」
3. 在系统弹窗中再次点击「打开」

如果仍然无法启动：

1. 前往「系统设置 → 隐私与安全性」
2. 点击「仍要打开」

已签名并公证的发布版本不需要此步骤。

## GUI 使用指南

### 唤起覆盖层

按下 `Shift + Command + Space`，一个毛玻璃效果面板会从屏幕中央弹出，输入框自动聚焦。

### 基本按键

| 按键 | 行为 |
|------|------|
| `Enter` | 保存当前输入并关闭面板 |
| `Shift + Enter` | 插入换行 |
| `Esc` | 取消输入 / 退出当前模式并关闭面板 |
| `↓` | 打开最近笔记 |
| `Tab` | 在输入框和结果列表之间切换焦点 |

### 斜杠命令

在输入框中以 `/` 开头：

| 命令 | 描述 |
|------|------|
| `/tail` | 显示最近的想法 |
| `/tail 20` | 显示最近 20 条（可指定数量） |
| `/search <查询>` | 全文搜索 |
| `/today` | 显示今天的想法 |
| `/tag <标签>` | 按标签筛选 |
| `/archive` | 查看已归档的想法 |
| `/keys` | 显示快捷键帮助 |
| `/hide` | 隐藏结果面板 |
| `/help` | 显示帮助 |
| `/exit` | 关闭面板 |

输入过程中会自动为斜杠命令提供补全建议。

### 结果浏览

结果面板打开后：

| 操作 | 描述 |
|------|------|
| `↑/↓` | 在结果列表中移动 |
| `Enter` | 复用选中的想法内容作为新输入草稿 |
| `Cmd + C` | 复制选中想法的内容 |
| `Cmd + P` | 切换置顶状态 |
| `Cmd + Delete` | 切换归档状态 |
| `Cmd + E` | 编辑选中的想法 |

### 编辑已有想法

从结果浏览中：
1. 选中一条想法
2. 按 `Cmd + E` 进入编辑模式

编辑行为：
- `Enter` 保存更新
- `Esc` 取消编辑，回到结果浏览

## CLI 使用指南

`thought` CLI 设计用于脚本、自动化和 agent 工作流。

```bash
./.build/debug/thought <command> [options]
```

### 查询命令

**`list`** — 列出想法，支持多种过滤条件

```bash
./.build/debug/thought list
./.build/debug/thought list --limit 50 --json
./.build/debug/thought list --from 7d --tag work
```

**`tail`** — 显示最近的 n 条想法（默认 50 条）

```bash
./.build/debug/thought tail
./.build/debug/thought tail 100 --json
./.build/debug/thought tail --from 30d --json
```

**`search`** — 全文搜索

```bash
./.build/debug/thought search 聚类
./.build/debug/thought search "检索 排序" --json
./.build/debug/thought search 规划 --limit 20 --offset 50
```

**`export`** — 导出为 JSON

```bash
./.build/debug/thought export --json
./.build/debug/thought export --from 7d --json
./.build/debug/thought export --source human --channel gui --json
```

**`stats`** — 统计概览

```bash
./.build/debug/thought stats
./.build/debug/thought stats --json
```

输出：总数、活跃天数、第一条和最后一条的时间。

**`days`** — 按日汇总

```bash
./.build/debug/thought days --limit 14
./.build/debug/thought days --from 30d --json
```

**`get`** — 按 ID 获取单条想法

```bash
./.build/debug/thought get <id>
```

### 写入命令

**`add`** — 添加新想法（测试和自动化场景）

```bash
./.build/debug/thought add "这是个想法 #测试"
echo "从 stdin 输入" | ./.build/debug/thought add
./.build/debug/thought add --tag work --pinned "重要想法"
```

**`update`** — 更新已有想法

```bash
./.build/debug/thought update <id> --content "新内容"
./.build/debug/thought update <id> --tag work --pinned --unarchived
./.build/debug/thought update <id> --clear-tags
```

**`delete`** — 删除想法

```bash
./.build/debug/thought delete <id>
```

### 归档过滤

大多数查询命令支持：

```bash
--archived    # 只显示已归档
--unarchived  # 只显示未归档（默认行为）
```

### 通用选项

- `--limit N`：限制结果数量
- `--offset N`：分页偏移
- `--from <时间>`：起始时间（支持 `30m`、`2h`、`7d`、`2w` 等相对格式，也支持 `2025-01-01` 等绝对格式）
- `--to <时间>`：结束时间
- `--source <值>`：按来源过滤
- `--channel <值>`：按渠道过滤
- `--tag <标签>`：按标签过滤（可重复使用）
- `--json`：JSON 格式输出
- `--archived` / `--unarchived`：归档状态

### Agent 工作流示例

```bash
# 导出过去 7 天所有 GUI 捕获的人类想法
./.build/debug/thought export --from 7d --source human --channel gui --json

# 分页查询更早的记录
./.build/debug/thought search "检索 排序" --offset 100 --limit 100 --json

# 查看每日汇总
./.build/debug/thought days --from 30d --json
```

## 标签系统

ThoughtStream 将内联标签视为捕获时的快捷方式，而非长期的事实来源。

### 支持的标签格式

单 token 标签，如 `#工作`、`#代码审查`、`#weekly_review`。标签不能包含空格。多词概念建议用 kebab-case 或 snake_case。

### 捕获语义

保存想法时：
- 内联 `#标签` token 会自动提取到结构化的 `tags` 字段
- 提取的标签保留在存储的 `content` 中

更新内容时：
- 内联 `#标签` 会重新解析
- 新检测到的标签会被添加
- 已有标签不会自动移除

### 示例

输入：`干完现在的活 #工作`

存储为：
- `content`：`干完现在的活 #工作`
- `tags`：`["工作"]`

## 存储架构

### 数据库位置

默认路径：

```
~/Library/Application Support/ThoughtStream/thoughts.sqlite3
```

### 开发环境覆盖

```bash
export THOUGHT_STREAM_HOME="$PWD/.thought-stream"
```

### 数据库结构

- **thoughts** 表：存储所有想法记录（id、content、created_at、updated_at、day、source、channel、tags_json、archived、pinned）
- **thoughts_fts** 虚拟表：使用 FTS5 全文检索引擎（unicode61 tokenizer）
- 索引：created_at、updated_at、day、archived、pinned
- PRAGMA：WAL 模式、synchronous = NORMAL、busy_timeout = 2000ms
- 写入使用事务（BEGIN IMMEDIATE），含回滚逻辑

### 清空本地数据

```bash
./scripts/clear_db.sh
```

## 设计哲学

ThoughtStream **不是**笔记软件或知识管理工具。它只做一件事：

> 用户按下一个全局快捷键后，屏幕中央弹出一个极简输入框。用户输入一条想法，按 Enter 保存，输入框立刻消失。用户不需要选择位置、不需要起标题、不需要分类、不需要管理任何内容。

### 产品原则

- **捕获阶段只负责记录，不负责整理**
- 不要做笔记编辑器
- 不要做知识库
- 不要做文档系统
- 不要做复杂 UI
- 不要让用户思考「这条内容应该放哪里」
- 用户只负责把想法输入进去
- 后续整理、总结、归类可以交给 AI 在另一个阶段完成

### 项目有意偏向

- 追加优先的捕获
- 轻量的面板内检索
- 本地存储
- 为下游工作流提供显式 CLI 访问

### 项目有意避免

- 捕获时的繁杂组织
- 把覆盖层变成一个工作区
- 把所有工作流都塞进 GUI

## 当前状态

当前版本已支持：

- 原生 macOS 覆盖层捕获
- 以查询为中心的 CLI
- 覆盖层中的斜杠命令
- 轻量结果复用和 GUI 编辑
- 发布打包脚本（.app、.zip、.dmg）

## 相关文档

- [快速入门](docs/getting-started.md)
- [CLI 指南](docs/cli.md)
- [标签系统](docs/tags.md)
- [存储架构](docs/storage.md)
- [发布与分发](docs/distribution.md)
- [路线图](ROADMAP.md)

## 许可证

许可证尚未确定。
