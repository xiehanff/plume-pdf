# Windows 安装包生成与分发

> 文档基线：Plume PDF `v0.1.0`，更新于 2026-09-02。

本文记录 Windows Release / Inno Setup 安装包生成方式，以及当前 GitHub Actions 自动发布行为。

## 1. 前置条件

- 使用项目固定 Flutter 版本：`fvm`
- 本机安装 Inno Setup 6

## 2. 本地生成安装包

推荐：

```powershell
.\make.cmd package-windows
```

这条命令会构建最新 Windows Release，并调用 `windows/installer/build_installer.ps1` 生成 setup。

手动执行：

```powershell
fvm flutter build windows --release
& .\windows\installer\build_installer.ps1 -SkipBuild
```

如果希望脚本自己构建：

```powershell
& .\windows\installer\build_installer.ps1
```

## 3. 版本与输出位置

v0.1.0 对应：

```text
pubspec version: 0.1.0+24
msix_version:     0.1.0.0
```

Inno Setup 输出格式：

```text
windows/installer/dist/PlumePDF_Setup_<version>.exe
```

版本来自 `pubspec.yaml`，不要在脚本或文档里额外维护第二份业务版本号。

## 4. 安装器行为

安装器会：

- 安装到 `C:\Program Files\Plume PDF`
- 创建桌面快捷方式
- 创建开始菜单入口
- 注册 `.pdf` 文件关联

## 5. GitHub Actions

`.github/workflows/build-desktop-packages.yml` 的 Windows job 使用 `windows-2022`：

```text
Checkout
→ Setup Flutter
→ Install Inno Setup
→ flutter pub get
→ flutter build windows --release
→ build_installer.ps1 -SkipBuild
→ upload-artifact *.exe
```

普通 `main` push 会生成 Windows Actions Artifact。

## 6. v0.1.0 正式发布

发布不需要手工打包或上传 EXE。

当 `main` 出现：

```text
version: 0.1.0+24
commit message: release: v0.1.0
```

工作流会自动创建/校验 `v0.1.0` tag。Windows EXE 会与：

- Linux DEB
- Linux RPM
- macOS DMG
- Android arm64 APK

一起进入同一个 GitHub Release。

Release 文案自动从 `CHANGELOG.md` 的 `0.1.0` 章节提取，因此版本文案、tag 和安装包都绑定同一 release commit。

## 7. 发布前 / 发布后自查

- Windows Release 构建通过
- Inno Setup 成功输出 EXE
- EXE 已进入 Actions Artifact
- GitHub Release 页面已上传 EXE
- 安装后主程序存在
- 桌面 / 开始菜单快捷方式存在
- PDF “打开方式”中可以选择 Plume PDF
- 双击 PDF 可以把文件路径传给应用并打开
- 应用版本为 `0.1.0`
- 卸载行为正常

## 8. 常见发布问题

### Release 没有创建

确认：

```text
pubspec.yaml == 0.1.0+24
head commit message == release: v0.1.0
```

### 普通 main push 只有 Artifact，没有 Release

这是预期行为。普通开发提交只验证桌面打包；只有 release commit / release tag 才进入 GitHub Release 聚合流程。
