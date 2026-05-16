# 分发指南

ThoughtStream 有四种独立的分发层次：

1. 本地开发安装
2. 未签名公开测试版
3. 签名发布打包
4. 可选公证

## 本地开发

本地测试时，继续使用：

```bash
./scripts/install_app.sh
```

该脚本构建 Debug 版 App Bundle，安装到 `/Applications` 并启动。

## 发布产物

构建 Release 版：

```bash
APP_VERSION=0.1.0 APP_BUILD=1 ./scripts/package_release.sh
```

生成产物：

- `dist/ThoughtStream.app`
- `dist/ThoughtStream.zip`
- `dist/ThoughtStream-<version>-<arch>.dmg`
- `dist/ThoughtStream-<version>-checksums.txt`

DMG 为拖拽安装盘，包含：

- `ThoughtStream.app`
- 一个指向 `/Applications` 的快捷方式

打包脚本同时会验证 App Bundle 的完整性，如果环境中安装了 `gh`，还会尝试将产物上传到对应的 GitHub Release。

## 未签名公开测试版

如果没有 Developer ID 证书，仍可发布 `ThoughtStream.zip` 或 `ThoughtStream.dmg`，供愿意手动绕过 Gatekeeper 的技术用户使用。

适用对象：

- 测试人员
- 内部用户
- 了解 macOS 安全提示的早期采用者

不适用场景：

- 主流公开发布
- 期望双击安装无警告的用户
- 有严格设备管理策略的环境

发布未签名版本时，请明确说明：

- 应用未签名或仅使用 ad hoc 签名
- macOS 可能在首次启动时显示开发者验证警告
- 用户可能需要在 Finder 中右键应用并选择「打开」
- 附带了校验和文件，可手动验证

## 签名发布

如果拥有 Developer ID Application 证书，通过环境变量传入：

```bash
SIGNING_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
APP_VERSION=0.1.0 \
APP_BUILD=1 \
./scripts/package_release.sh
```

该命令会在生成发布产物前，使用 hardened runtime 对 App Bundle 进行签名。

## 公证

如果已配置 `notarytool` 钥匙串配置文件，可以对 ZIP 产物进行公证：

```bash
SIGNING_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
NOTARY_PROFILE="thoughtstream-notary" \
APP_VERSION=0.1.0 \
APP_BUILD=1 \
./scripts/package_release.sh
```

脚本流程：

1. 构建 Release 版 App
2. 对 App 签名
3. 验证 Bundle
4. 创建 ZIP
5. 通过 `notarytool` 提交 ZIP
6. 对 App 进行 staple
7. 从已 stapled 的 App 重新构建 ZIP

## 验证

检查已构建的 App Bundle：

```bash
./scripts/validate_release.sh
```

或指定具体路径：

```bash
./scripts/validate_release.sh ./dist/ThoughtStream.app
```

默认情况下，验证脚本允许 ad hoc 本地构建在 Gatekeeper 评估中失败而不报错。

如果希望 Gatekeeper 拒绝时验证失败：

```bash
STRICT_GATEKEEPER=1 ./scripts/validate_release.sh
```

## 首次启动帮助

未签名或 ad hoc 本地构建即使 ZIP 或 DMG 下载正确，仍可能被 Gatekeeper 在首次启动时阻止。

遇到此情况：

1. 解压 ZIP 或挂载 DMG
2. 将 `ThoughtStream.app` 拖到 `/Applications`
3. 在 Finder 中右键 `ThoughtStream.app` 选择「打开」
4. 在系统弹窗中再次点击「打开」

如果 Finder 仍然阻止启动：

1. 前往「系统设置 → 隐私与安全性」
2. 在页面下方找到被阻止的 `ThoughtStream.app` 提示
3. 点击「仍要打开」

已签名并公证的发布版本无需此额外步骤。
