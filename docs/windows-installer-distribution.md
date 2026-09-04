# Windows 安装包生成与分发

> 文档基线：`main @ c19c2f82eec37940635168ab42cc731ab4f61ef6`，更新于 2026-09-04。
>
> 当前 `pubspec.yaml`：`0.1.3+27`，`msix_version: 0.1.3.0`；最新 GitHub Release：`v0.1.3`。

本文记录当前 Windows Release / Inno Setup EXE 安装包生成方式，以及 GitHub Actions 自动发布行为。

## 1. 前置条件

- 项目本地命令使用 FVM Flutter
- 安装 Inno Setup 6
- Windows x64

## 2. 本地生成安装包

推荐：

```powershell
.\make.cmd package-windows
```

或直接：

```powershell
powershell -ExecutionPolicy Bypass -File .\windows\installer\build_installer.ps1
```

脚本默认会执行：

```text
fvm flutter build windows --release --verbose
↓
寻找 ISCC.exe
↓
读取 pubspec.yaml 的 version name
↓
编译 windows/installer/plume_pdf.iss
```

如果已经有最新 Windows Release Bundle：

```powershell
& .\windows\installer\build_installer.ps1 -SkipBuild
```

## 3. 版本来源

当前：

```text
pubspec version: 0.1.3+27
msix_version:     0.1.3.0
```

Inno Setup 脚本实际使用 `pubspec.yaml` 中 `+` 前面的版本：

```text
0.1.3+27
↓
MyAppVersion = 0.1.3
```

输出：

```text
windows/installer/dist/PlumePDF_Setup_0.1.3.exe
```

通用格式：

```text
windows/installer/dist/PlumePDF_Setup_<version-name>.exe
```

不要在文档或 PowerShell 中再维护第二份 Inno Setup 业务版本号。

`msix_config` 仍保留在 `pubspec.yaml`，仓库也保留独立 MSIX 构建入口；但当前 GitHub Release 的 Windows 正式产物是 **Inno Setup EXE**，不是 MSIX。

## 4. 安装器行为

`windows/installer/plume_pdf.iss` 当前会：

- 安装到 `{autopf}\Plume PDF`，通常是 `C:\Program Files\Plume PDF`
- 创建开始菜单入口
- 默认提供桌面快捷方式任务
- 注册 `.pdf` Open With / ProgID
- 把 `%1` 文件路径传给 `plume_pdf.exe`
- 卸载时清理安装器创建的关联键

主程序：

```text
plume_pdf.exe
```

安装器 `AppId` 固定，因此升级安装会识别为同一产品。

## 5. PDF 文件打开链路

Inno Setup 注册的 open command：

```text
"<install-dir>\plume_pdf.exe" "%1"
```

应用侧会从启动参数读取 PDF 路径；Windows Reader 的启动文件链路由 `AppLaunchArgs` 与 `Platform.executableArguments` 处理。

验收应包含：

```text
资源管理器右键“打开方式”
↓
Plume PDF
↓
启动应用
↓
打开对应 PDF
```

以及双击已经关联的 PDF。

## 6. GitHub Actions

`.github/workflows/build-desktop-packages.yml` 的 Windows job 当前固定：

```text
runs-on: windows-2022
Flutter: 3.41.9
```

流程：

```text
Checkout
↓
Setup Flutter
↓
choco install innosetup
↓
flutter pub get
↓
flutter build windows --release
↓
build_installer.ps1 -SkipBuild
↓
upload windows/installer/dist/*.exe
```

普通 `main` push 只生成 Windows Actions Artifact，不自动创建 GitHub Release。

## 7. 正式 Release

通用约定：

```text
pubspec.yaml: version: X.Y.Z+N
head commit:  release: vX.Y.Z
```

当前 `v0.1.3` 对应：

```text
version:      0.1.3+27
msix_version: 0.1.3.0
release tag:  v0.1.3
```

发布模式会把 Windows EXE 与：

- Linux DEB
- Linux RPM
- macOS DMG
- Android arm64 APK

聚合到同一个 GitHub Release。

Release Notes 从 `CHANGELOG.md` 对应的：

```text
## X.Y.Z
```

章节提取。

当前 Build Packages workflow 同时监听：

```text
main push
v* tag push
```

release commit 的 main run 会创建/校验 tag；tag push 随后还会再触发一轮 Build Packages。这是当前 workflow 的实际行为。

## 8. 当前 Windows 发布验收

至少检查：

- Windows Release 构建成功
- `PlumePDF_Setup_<version>.exe` 生成
- Actions Artifact 包含 EXE
- GitHub Release 包含 EXE
- 安装目录正确
- 桌面 / 开始菜单入口正确
- PDF “打开方式”可见 Plume PDF
- 双击 PDF 能把文件路径传给应用
- 应用版本与 `pubspec.yaml` 对应
- Reader Escape 可退出 AI 框选
- AI streaming Stop 正常
- 连续翻译/解释/深度理解不会长期排队等待旧请求
- 卸载后安装目录与安装器注册项清理正常

## 9. 常见问题

### 找不到 `ISCC.exe`

`build_installer.ps1` 会依次尝试：

- PATH 中的 `iscc.exe`
- Program Files (x86) / Inno Setup 6
- `%LOCALAPPDATA%\Programs\Inno Setup 6`
- Start Menu 中 Inno Setup Compiler 快捷方式目标目录

仍找不到时会直接失败，不会静默跳过安装器生成。

### 普通 main push 没有 GitHub Release

这是当前设计：普通提交只做 package verification / Artifact；只有 release commit 或 release tag 才进入 Release 聚合路径。

### EXE 版本和 `+build` 不一致

这是预期行为。Inno Setup `AppVersion` 使用 `0.1.3` 这样的 version name；Flutter build number `+27` 不写入安装器文件名。完整版本/build number仍由 Flutter 工程元数据维护。
