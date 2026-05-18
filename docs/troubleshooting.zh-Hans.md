# 故障排查

## 应用打不开

如果 ThoughtStream 是本地构建的，或者下载的是未签名构建：

1. 先把 `ThoughtStream.app` 放到 `/Applications`
2. 在 Finder 中右键它并选择「打开」
3. 在系统弹窗中再次确认

如果 macOS 仍然阻止启动：

1. 打开「系统设置 → 隐私与安全性」
2. 找到被阻止应用的提示
3. 点击「仍要打开」

更多背景说明见 [分发文档](distribution.zh-Hans.md)。

## 热键看起来没有反应

按下面顺序检查：

1. 确认 ThoughtStream 仍然在菜单栏里运行
2. 关闭并重新打开应用
3. 检查是否有别的工具占用了 `Shift + Command + Space`

目前 ThoughtStream 默认使用这个快捷键，还没有提供自定义热键设置。

## 找不到 `thought` 命令

可以先试下面几种方式：

1. 直接运行打包出来的二进制，例如 `./.build/debug/thought`
2. 重新执行 `./scripts/install_app.sh`
3. 检查 `/usr/local/bin/thought` 是否存在

安装流程会尝试在那里创建一个软链接；如果那一步失败了，可能需要手动创建。

## 改了存储位置后，旧笔记不见了

这通常意味着 ThoughtStream 当前指向的是另一份数据库。

先执行：

```bash
thought config show
```

然后把输出路径和下面几个位置对照一下：

- 你之前使用的自定义存储目录
- 默认目录 `~/Library/Application Support/ThoughtStream`

另外要记住：

- `Reset Storage Location` 不会自动把数据迁回默认目录
- `--keep-destination` 的语义就是保留目标库，并丢弃当前本地库

完整机制见 [存储文档](storage.zh-Hans.md)。

## 不确定迁移时该选哪个选项

可以这样判断：

- `--overwrite`：当前数据库才是你信任的那份，需要用它覆盖目标库
- `--merge`：两边数据库都有价值，希望把它们合并在一起，并跳过重复 id
- `--keep-destination`：目标库才是权威来源，你只是想切换过去

## 搜索结果比预期少

先检查是不是某个过滤条件把结果缩小了：

- `--from`
- `--to`
- `--source`
- `--channel`
- `--archived` 或 `--unarchived`

在覆盖层里，也确认自己用的是正确命令：

- `/search <query>`：全文搜索
- `/archive`：查看已归档笔记
- `/tag <tag>`：按单个标签筛选
