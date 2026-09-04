# Linux Debian Package Distribution

> 文档基线：`main @ c19c2f82eec37940635168ab42cc731ab4f61ef6`，更新于 2026-09-04。
>
> 当前 `pubspec.yaml`：`0.1.3+27`；最新 GitHub Release：`v0.1.3`。

本文记录当前 Linux Release Bundle、Debian `.deb` 打包脚本与 GitHub Actions 行为。

## 1. 前置条件

本地脚本默认使用项目 FVM Flutter：

```text
fvm flutter
```

并要求系统存在：

```bash
dpkg-deb
```

Ubuntu/Debian 可通过系统包管理器安装相关工具。

## 2. 生成 DEB

推荐：

```bash
make package-deb
```

等价于：

```bash
bash scripts/build_linux_deb.sh
```

脚本会：

```text
读取 pubspec.yaml version
↓
必要时 fvm flutter build linux --release --verbose
↓
读取 build/linux/x64/release/bundle
↓
组装 DEBIAN/control + desktop entry + hicolor icons
↓
dpkg-deb --build --root-owner-group
```

当前版本输出示例：

```text
build/linux/x64/release/plume-pdf_0.1.3+27_amd64.deb
```

通用格式：

```text
build/linux/x64/release/plume-pdf_<pubspec-version>_amd64.deb
```

若已经有最新 Linux Release Bundle：

```bash
./scripts/build_linux_deb.sh --skip-build
```

## 3. Linux Release Bundle

单独构建：

```bash
fvm flutter build linux --release --verbose
```

Bundle：

```text
build/linux/x64/release/bundle/
```

脚本会验证：

```text
build/linux/x64/release/bundle/plume_pdf
```

必须存在且可执行。

## 4. DEB 安装布局

当前 DEB 安装主目录是：

```text
/opt/plume_pdf
```

主程序：

```text
/opt/plume_pdf/plume_pdf
```

desktop entry：

```text
/usr/share/applications/com.example.plume_pdf.desktop
```

图标安装到：

```text
/usr/share/icons/hicolor/
```

`postinst` 会尽力刷新：

```text
gtk-update-icon-cache
update-desktop-database
```

注意：当前 RPM 使用 `/opt/plume-pdf`，与 DEB 的 `/opt/plume_pdf` 仍不一致。这是当前代码的真实安装布局；切换 DEB/RPM 包格式测试时应注意旧目录残留。

## 5. 安装 / 重装 / 卸载测试

安装：

```bash
sudo apt install ./build/linux/x64/release/*.deb
```

依赖需要补齐时：

```bash
sudo apt install -f
```

覆盖安装后若怀疑仍启动旧二进制，优先确认：

```bash
which plume_pdf
ls -l /opt/plume_pdf/plume_pdf
```

以及桌面入口中的 `Exec=` 是否指向：

```text
/opt/plume_pdf/plume_pdf
```

验收至少包含：

- 应用菜单可以找到 `Plume PDF`
- 图标正确
- 应用能启动并打开 PDF
- `.pdf` desktop integration 正常
- 版本与 `pubspec.yaml` 对应
- Reader Escape / AI 框选行为正常
- AI streaming Stop 可终止当前输出
- 连续触发翻译/解释/深度理解不会长期堆积后台请求

## 6. GitHub Actions

`.github/workflows/build-desktop-packages.yml` 在普通 `main` push 时执行 Linux job：

```text
flutter pub get
↓
flutter build linux --release
↓
build_linux_deb.sh --skip-build
↓
build_linux_rpm.sh --skip-build
↓
upload DEB + RPM artifact
```

CI 使用 workflow 固定的 Flutter `3.41.9`，不会通过 FVM 调用。

## 7. Release 约定

当前版本元数据：

```text
version: 0.1.3+27
```

正式发布通用约定：

```text
pubspec.yaml: version: X.Y.Z+N
head commit:  release: vX.Y.Z
```

`release_meta` 会：

```text
解析 X.Y.Z
↓
创建/校验 vX.Y.Z tag
↓
Linux DEB + RPM
Windows EXE
macOS DMG
Android arm64 APK
↓
从 CHANGELOG.md 提取对应版本说明
↓
创建/更新 GitHub Release
```

当前 workflow 同时监听 `main` 和 `v*` tag。release commit 在 main run 中创建 tag 后，tag push 会再触发一次 Build Packages run；查看 Actions 时这是当前预期代码路径，不代表 DEB 被人工重复构建。

## 8. 发布验收

以当前 `v0.1.3` / `0.1.3+27` 为例，至少检查：

- Linux release bundle 成功
- DEB 成功生成
- RPM 成功生成
- Actions Artifact 中同时存在 DEB/RPM
- GitHub Release 中 Linux 包存在
- DEB 文件版本与 `pubspec.yaml` 对应
- 安装后实际执行的是 `/opt/plume_pdf/plume_pdf`
- 卸载/重装后桌面入口和图标缓存正常

如果 Release job 未执行，先检查：

```text
commit message 是否严格为 release: vX.Y.Z
pubspec.yaml 是否为 X.Y.Z+N
CHANGELOG.md 是否有 ## X.Y.Z 章节
```
