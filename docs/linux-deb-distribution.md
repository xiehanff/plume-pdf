# Linux Debian Package Distribution

> 文档基线：Plume PDF `v0.1.2`，更新于 2026-09-03。

本文记录 Linux Release Bundle、Debian `.deb` 打包方式，以及当前 GitHub Release 自动化行为。

## 1. 前置条件

- 使用项目固定 Flutter 版本：`fvm`
- 本机安装 `dpkg-deb`

## 2. 自动生成 DEB

```bash
make package-deb
```

脚本读取 `pubspec.yaml` 的版本号，必要时构建 Linux Release Bundle，并组装 Debian 元数据、desktop entry 与图标。

当前 v0.1.2 应用版本：

```text
0.1.2+26
```

输出格式：

```text
build/linux/x64/release/plume-pdf_<version+build>_amd64.deb
```

若已有最新 Release Bundle：

```bash
./scripts/build_linux_deb.sh --skip-build
```

## 3. 单独构建 Linux Release

```bash
fvm flutter build linux --release --verbose
```

Bundle 位于：

```text
build/linux/x64/release/bundle/
```

## 4. 安装测试

```bash
sudo apt install ./build/linux/x64/release/*.deb
```

必要时：

```bash
sudo apt install -f
```

安装后检查：

- 应用菜单能找到 `Plume PDF`
- 图标正确
- 应用可启动并打开 PDF
- `.pdf` desktop integration 正常
- 应用内版本号与 `pubspec.yaml` 一致
- AI 流式生成时发送按钮可切换为停止，并能立即终止当前输出

## 5. 图标 / 桌面入口

当前 desktop entry 与图标使用 `com.example.plume_pdf` 名称，二者必须保持一致。安装脚本会刷新图标缓存和 desktop database。

常见排查：

| 问题 | 处理 |
|---|---|
| 菜单无图标 | 检查 `Icon=` 与 hicolor 文件名是否一致 |
| 图标缓存未刷新 | `sudo gtk-update-icon-cache -f /usr/share/icons/hicolor/` |
| 菜单入口未刷新 | `sudo update-desktop-database /usr/share/applications/` |

## 6. GitHub Actions

`.github/workflows/build-desktop-packages.yml` 在普通 `main` push 时自动：

```text
flutter build linux --release
→ build_linux_deb.sh --skip-build
→ build_linux_rpm.sh --skip-build
→ upload DEB + RPM Actions Artifact
```

RPM 在 Ubuntu runner 上使用已验证的 `rpmbuild --nodeps` 路径，只绕过 RPM 数据库无法识别 apt 安装依赖的问题；实际 `rpmbuild` / `patchelf` 命令仍会先检查存在。

## 7. v0.1.2 自动发布流程

正式版本不需要手工上传 DEB。

当 `main` 的发布提交满足：

```text
pubspec.yaml: version: 0.1.2+26
commit message: release: v0.1.2
```

`Build Packages` 会：

```text
解析 0.1.2
→ 创建/校验 v0.1.2 tag
→ 构建 Linux DEB + RPM
→ 构建 Windows EXE
→ 构建 macOS DMG
→ 构建 Android arm64 APK
→ 等待所有 release jobs 成功
→ 从 CHANGELOG.md 提取 0.1.2 Release Notes
→ 创建 GitHub Release
→ 上传全部安装包
```

因此正式 Release 页面中的 DEB 与其他平台包来自同一个发布提交和同一个 tag。

## 8. 发布验收

v0.1.2 发布后至少确认：

- Linux job 成功
- DEB Artifact 存在
- RPM Artifact 存在
- GitHub Release 中 DEB/RPM 均已上传
- DEB 文件中的版本与 `0.1.2+26` 对应
- 安装后应用可启动并打开 PDF

如果 Release job 未执行，优先检查发布提交消息是否严格为 `release: v0.1.2`，以及 `pubspec.yaml` 版本是否为 `0.1.2+26`。
