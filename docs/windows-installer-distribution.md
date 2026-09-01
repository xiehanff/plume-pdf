# Windows 安装包生成与分发

本文记录当前 Windows Release / Inno Setup 安装包生成方式，以及 GitHub Actions 发布行为。

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

## 3. 输出位置

```text
windows/installer/dist/PlumePDF_Setup_<version>.exe
```

版本来自 `pubspec.yaml`，不要在文档中固定旧版本文件名。

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

普通 `main` push 会生成 Actions Artifact。

当明确推送 `v*` tag 时，Windows EXE 会和 Linux DEB/RPM、macOS DMG、Android APK 一起进入同一个 GitHub Release。

## 6. 发布前自查

- Windows Release 构建通过
- Inno Setup 成功输出 EXE
- 安装后主程序存在
- 桌面/开始菜单快捷方式存在
- PDF “打开方式”中可以选择 Plume PDF
- 双击 PDF 可以把文件路径传给应用并打开
- 卸载行为正常

## 7. 当前 CI 状态

移动端合并前已重新跑过完整 Windows release + installer + Artifact 上传，链路通过。
