# Linux RPM Package Distribution

> 文档基线：`main @ c19c2f82eec37940635168ab42cc731ab4f61ef6`，更新于 2026-09-04。
>
> 当前 `pubspec.yaml`：`0.1.3+27`；最新 GitHub Release：`v0.1.3`。

本文记录当前 Fedora/Linux RPM 打包脚本、安装布局与 GitHub Hosted runner 兼容逻辑。

## 1. 本地前置条件

Fedora：

```bash
sudo dnf install rpm-build patchelf
```

项目本地打包脚本使用 FVM Flutter：

```text
fvm flutter
```

## 2. 生成 RPM

推荐：

```bash
make package-rpm
```

等价于：

```bash
bash scripts/build_linux_rpm.sh
```

脚本会从 `pubspec.yaml` 拆出：

```text
0.1.3+27
↓
app_version = 0.1.3
app_release = 27
```

然后：

```text
必要时构建 Linux Release Bundle
↓
打包 bundle / icons / desktop entry 为 rpmbuild SOURCES
↓
rpmbuild --nodeps
  --define app_version
  --define app_release
↓
复制最终 RPM 到 build/linux/x64/release/
```

当前输出格式类似：

```text
build/linux/x64/release/plume-pdf-0.1.3-27.<dist>.x86_64.rpm
```

若已有最新 Release Bundle：

```bash
./scripts/build_linux_rpm.sh --skip-build
```

## 3. RPM 安装布局

当前 RPM 安装主目录：

```text
/opt/plume-pdf
```

主程序：

```text
/opt/plume-pdf/plume_pdf
```

desktop entry：

```text
/usr/share/applications/com.example.plume_pdf.desktop
```

图标：

```text
/usr/share/icons/hicolor/
```

RPM spec 会使用 `patchelf` 把 Flutter bundle 的运行时 RPATH 收敛为：

```text
主程序: $ORIGIN/lib
共享库: $ORIGIN
```

注意：当前 DEB 安装在 `/opt/plume_pdf`，RPM 安装在 `/opt/plume-pdf`。两套路径尚未统一；切换安装格式时需要检查旧目录和 desktop entry 是否残留。

## 4. 安装 / 重装 / 卸载

安装：

```bash
sudo dnf install ./build/linux/x64/release/*.rpm
```

已有同版本或需要覆盖验证时，可使用：

```bash
sudo dnf reinstall ./build/linux/x64/release/*.rpm
```

卸载：

```bash
sudo dnf remove plume-pdf
```

验收：

- 应用菜单与图标正常
- 实际执行 `/opt/plume-pdf/plume_pdf`
- PDF 可以打开
- 文件管理器“打开方式”链路正常
- 包版本与 `pubspec.yaml` 一致
- Reader Escape / AI 框选行为正常
- Stop streaming 可结束当前输出并保留已经收到的部分回复
- 连续 Tool Action 使用 latest-wins，不应出现长时间后台排队

## 5. Ubuntu Hosted runner 的 `--nodeps`

GitHub Hosted Linux runner 使用 Ubuntu。

`patchelf` 通过 apt/dpkg 安装，但 `rpmbuild` 的 `BuildRequires` 只看 RPM package database，因此会出现：

```text
patchelf 命令真实存在
↓
rpmbuild package database 却认为缺失
```

当前脚本先明确检查：

```bash
command -v rpmbuild
command -v patchelf
```

确认真实命令存在后，再运行：

```text
rpmbuild --nodeps
```

这里的 `--nodeps` 只绕过 RPM 数据库无法识别 apt 安装记录的问题，不代表脚本不检查所需工具。

## 6. `packaging/plume-pdf.spec`

构建脚本会通过 `--define` 覆盖 spec 顶部的 fallback：

```text
app_version
app_release
```

因此正式脚本构建时，spec 文件里的历史默认 `0.0.16 / 17` 不决定最终包版本。

当前 spec 的安装目录是 `/opt/plume-pdf`，并负责 desktop entry、hicolor icons 与 RPATH 修正。

另外，仓库根 `LICENSE` 当前是 MIT，但 `packaging/plume-pdf.spec` 的 `License:` 字段仍写为 `Proprietary`。这是当前源码中的元数据不一致；后续如果修改 spec，应把两者同步，不要以本文旧值为准。

## 7. CI / Release

普通 `main` push：

```text
flutter build linux --release
↓
build_linux_deb.sh --skip-build
↓
build_linux_rpm.sh --skip-build
↓
上传 Linux DEB + RPM Actions Artifact
```

正式发布通用约定：

```text
pubspec.yaml: version: X.Y.Z+N
head commit:  release: vX.Y.Z
```

当前 `0.1.3+27` 对应：

```text
RPM Version: 0.1.3
RPM Release: 27
```

发布模式中，RPM 会和：

- DEB
- Windows EXE
- macOS DMG
- Android arm64 APK

一起进入 GitHub Release。

当前 Build Packages 同时监听 `main` 和 `v*` tag；main release run 创建 tag 后，tag push 还会再次触发 workflow。这是当前 Actions 行为。

## 8. 排查

### `patchelf` BuildRequires 缺失

先确认当前脚本仍走：

```text
command 检查
→ rpmbuild --nodeps
```

不要为了 Ubuntu runner 去伪造 RPM package database。

### 安装后看起来像旧版本

先执行：

```bash
rpm -q plume-pdf
rpm -ql plume-pdf | grep plume_pdf
ls -l /opt/plume-pdf/plume_pdf
```

必要时使用 `dnf reinstall`，并检查是否曾经安装过 DEB 版本留下 `/opt/plume_pdf`。
