# 快速入门

## ThoughtStream 是什么

ThoughtStream 有两个入口：

- **`ThoughtStreamApp`**
  - macOS 覆盖层，用于捕获想法和轻量检索
- **`thought`**
  - CLI，用于查询、导出和自动化

典型工作流是：

1. 先在覆盖层里快速记下
2. 继续工作
3. 之后再回来搜索、筛选、汇总

## 构建

```bash
env HOME=$PWD/.home CLANG_MODULE_CACHE_PATH=$PWD/.build/ModuleCache swift build --product ThoughtStreamApp
env HOME=$PWD/.home CLANG_MODULE_CACHE_PATH=$PWD/.build/ModuleCache swift build --product thought
```

## 运行应用

开发调试：

```bash
./.build/debug/ThoughtStreamApp
```

构建原生 App Bundle：

```bash
./scripts/build_app.sh
open ./dist/ThoughtStream.app
```

构建、安装到 `/Applications` 并启动（一步完成）：

```bash
./scripts/install_app.sh
```

这个安装脚本也会尝试创建 `/usr/local/bin/thought`。

## 首次启动

未签名或 ad hoc 本地构建可能需要在首次启动时进行一次手动授权。

遇到此情况：

1. 将 `ThoughtStream.app` 拖到 `/Applications`
2. 在 Finder 中右键 `ThoughtStream.app` 选择「打开」
3. 在系统弹窗中再次点击「打开」

如果仍然不行：

1. 前往「系统设置 → 隐私与安全性」
2. 点击「仍要打开」

已签名并公证的发布版本无需此额外步骤。

## 覆盖层基础操作

使用以下快捷键唤出覆盖层：

```text
Shift + Command + Space
```

基本按键：

- `Enter` 保存当前输入
- `Shift + Enter` 插入换行
- `Esc` 会根据当前状态执行返回、取消编辑、收起结果或关闭面板
- `↓` 在输入为空时打开最近笔记
- `Tab` 在输入框和结果浏览之间切换

## 第一次可以试的命令

在覆盖层里先试试这些：

- `/tail`
- `/tail 20`
- `/search onboarding`
- `/today`
- `/tag work`
- `/archive`
- `/keys`
- `/help`

`/help` 用来看命令列表，`/keys` 用来看快捷键列表。

## 结果浏览

当结果面板打开时：

- `↑/↓` 在结果列表中移动
- `Enter` 将选中的笔记内容复用为新的草稿
- `Cmd + C` 复制选中笔记的内容
- `Cmd + D` 删除选中的笔记
- `Cmd + P` 切换置顶状态
- `Cmd + Delete` 切换归档状态
- `Cmd + E` 编辑选中的笔记

## 编辑已有笔记

在结果浏览中：

1. 选中一条笔记
2. 按 `Cmd + E`
3. 在输入框里修改内容
4. 按 `Enter` 保存，或按 `Esc` 取消

## 数据默认存放位置

默认数据库路径：

```text
~/Library/Application Support/ThoughtStream/thoughts.sqlite3
```

后续可以通过菜单栏应用或 `thought config set-root` 修改。

## 后续文档

- [覆盖层指南](overlay.zh-Hans.md)
- [CLI 指南](cli.zh-Hans.md)
- [标签](tags.zh-Hans.md)
- [存储](storage.zh-Hans.md)
- [分发](distribution.zh-Hans.md)
- [故障排查](troubleshooting.zh-Hans.md)
