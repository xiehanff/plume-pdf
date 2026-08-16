# Linux RPM Package Distribution

本文说明如何生成 Fedora/Linux RPM release 包，以及如何在 Fedora 上安装测试。

## 1. 前置条件

- 使用项目固定 Flutter 版本：`fvm`
- 已安装 `rpm-build` 和 `patchelf`：

```bash
sudo dnf install rpm-build patchelf
```

## 2. 生成 RPM

从项目根目录执行：

```bash
make package-rpm
```

脚本会先执行 `fvm flutter build linux --release`，再使用
`packaging/plume-pdf.spec` 生成 RPM。

本次 `0.0.13+11` 的输出文件为：

```text
build/linux/x64/release/plume-pdf-0.0.13-11.fc44.x86_64.rpm
```

文件名中的 `.fc44` 是 Fedora 发行版标识；在其他 Fedora 版本上构建时，该后缀会随系统 RPM 配置变化。

如果已经有最新的 Linux release bundle，可跳过 Flutter 构建：

```bash
./scripts/build_linux_rpm.sh --skip-build
```

## 3. 安装测试

```bash
sudo dnf install ./build/linux/x64/release/plume-pdf-0.0.13-11.fc44.x86_64.rpm
```

升级同一应用的后续版本时仍使用 `dnf install`；卸载时执行：

```bash
sudo dnf remove plume-pdf
```

## 4. 手动验收

- 应用菜单中能看到 `Plume PDF` 和正确图标。
- 应用可以启动并打开 PDF。
- 自定义标题栏可以拖动窗口。
- 最小化、最大化、关闭按钮可用，关闭按钮 hover 背景为红色。
- 操作栏右侧菜单上下留白一致，顶部左侧不再重复显示文件标题。
- 从文件管理器双击或使用“打开方式”打开 PDF 时，应用能加载传入文件。

## 5. GitHub Release

将生成的 `.rpm` 作为 `v0.0.13` Release asset 上传：

```bash
gh release upload v0.0.13 \
  build/linux/x64/release/plume-pdf-0.0.13-11.fc44.x86_64.rpm \
  --clobber
```
