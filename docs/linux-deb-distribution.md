# Linux Debian Package Distribution

本文记录 Plume PDF 的 Linux Release Bundle 与 Debian `.deb` 打包方式。

## 1. 前置条件

- 使用项目固定 Flutter 版本：`fvm`
- 本机安装 `dpkg-deb`

## 2. 自动生成 DEB

```bash
make package-deb
```

脚本读取 `pubspec.yaml` 的版本号，必要时构建 Linux Release Bundle，并组装 Debian 元数据、desktop entry 与图标。

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

## 5. 图标/桌面入口

当前 desktop entry 与图标使用 `com.example.plume_pdf` 名称，二者必须保持一致。安装脚本会刷新图标缓存和 desktop database。

常见排查：

| 问题 | 处理 |
|---|---|
| 菜单无图标 | 检查 `Icon=` 与 hicolor 文件名是否一致 |
| 图标缓存未刷新 | `sudo gtk-update-icon-cache -f /usr/share/icons/hicolor/` |
| 菜单入口未刷新 | `sudo update-desktop-database /usr/share/applications/` |

## 6. GitHub Actions

`.github/workflows/build-desktop-packages.yml` 在普通 `main` push 时会自动：

```text
flutter build linux --release
→ build_linux_deb.sh --skip-build
→ build_linux_rpm.sh --skip-build
→ upload DEB + RPM Artifact
```

RPM 在 Ubuntu runner 上使用已验证的 `rpmbuild --nodeps` 路径，只跳过 RPM 数据库无法识别 apt 安装依赖的问题；实际 `rpmbuild` / `patchelf` 命令仍会先检查存在。

## 7. Tag Release

明确推送 `v*` tag 时，DEB 会和 RPM、Windows EXE、macOS DMG、Android APK 一起被发布到同一个 GitHub Release，无需手动执行 `gh release upload`。

## 8. 当前验证状态

移动端合并前已重新验证 Linux release、DEB、RPM 和 Actions Artifact 上传全部成功。
