# Linux Debian Package Distribution

项目路径：项目根目录

这份文档只记录两件事：

- 如何生成 Linux `release` bundle
- 如何打包成 `.deb`

## 1. 前置条件

- 使用项目固定 Flutter 版本：`fvm`
- 本机已安装 `dpkg-deb`

## 2. 自动生成 DEB（推荐）

从项目根目录执行：

```bash
make package-deb
```

脚本会读取 `pubspec.yaml` 的版本号，必要时生成 Linux Release Bundle，组装
Debian 元数据、桌面入口和图标，并输出：

```text
build/linux/x64/release/plume-pdf_0.0.12+10_amd64.deb
```

如果已经有最新的 Linux Release Bundle，可跳过 Flutter 构建：

```bash
./scripts/build_linux_deb.sh --skip-build
```

## 3. 手动生成 Release Bundle

```bash
fvm flutter build linux --release --verbose
```

生成结果在：

```text
build/linux/x64/release/bundle/
```

## 4. 组装 Debian 包目录

```bash
pkg_root=/tmp/plume_pdf_deb_root
rm -rf "$pkg_root"
mkdir -p "$pkg_root/DEBIAN"
mkdir -p "$pkg_root/opt"
mkdir -p "$pkg_root/usr/share/applications"
mkdir -p "$pkg_root/usr/share/icons"
cp -a build/linux/x64/release/bundle "$pkg_root/opt/plume_pdf"
cp -a linux/icons/hicolor "$pkg_root/usr/share/icons/"
```

## 5. 写入 control 文件

```bash
cat > "$pkg_root/DEBIAN/control" <<'EOF'
Package: plume-pdf
Version: 0.0.12+10
Section: utils
Priority: optional
Architecture: amd64
Maintainer: xiehan <noreply@example.com>
Depends: libc6, libgtk-3-0, libglib2.0-0, libstdc++6
Description: Plume PDF
 A Flutter PDF reader packaged for Linux.
EOF
```

## 6. 安装桌面入口

```bash
cat > "$pkg_root/usr/share/applications/com.example.plume_pdf.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=Plume PDF
Exec=/opt/plume_pdf/plume_pdf
Icon=com.example.plume_pdf
Terminal=false
Categories=Office;Viewer;
StartupNotify=true
StartupWMClass=com.example.plume_pdf
X-GNOME-WMClass=com.example.plume_pdf
EOF
```

## 7. 检查图标文件名

当前源文件已经使用 `com.example.plume_pdf.png`，需要与 desktop entry 中的 `Icon=com.example.plume_pdf` 保持一致：

```bash
find linux/icons/hicolor -path '*/apps/com.example.plume_pdf.png' -print
```

## 8. postinst 脚本 — 安装后刷新图标缓存

安装后必须刷新图标缓存和桌面数据库，否则图标不会在应用菜单中出现。

```bash
cat > "$pkg_root/DEBIAN/postinst" <<'EOF'
#!/bin/sh
set -e
if command -v gtk-update-icon-cache >/dev/null 2>&1; then
  gtk-update-icon-cache -f /usr/share/icons/hicolor/ || true
fi
if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database /usr/share/applications/ || true
fi
chmod +x /opt/plume_pdf/plume_pdf
exit 0
EOF
chmod 755 "$pkg_root/DEBIAN/postinst"
```

## 9. 生成 `.deb`

```bash
dpkg-deb --build --root-owner-group "$pkg_root" /tmp/plume-pdf_0.0.12+10_amd64.deb
```

## 10. 安装测试

```bash
sudo apt install /tmp/plume-pdf_0.0.12+10_amd64.deb
# 如果缺少依赖
sudo apt install -f
```

安装后可在应用菜单中搜索 "Plume PDF"，图标应正常显示。

## 11. 输出位置

自动打包脚本输出到：

```text
build/linux/x64/release/plume-pdf_0.0.12+10_amd64.deb
```

按手动步骤生成时，输出位置由 `dpkg-deb --build` 命令决定；本文示例为：

```text
/tmp/plume-pdf_0.0.12+10_amd64.deb
```

## 12. 图标不显示的排查

| 问题 | 原因 | 解决 |
|---|---|---|
| 菜单中无图标 | desktop entry 中 `Icon=` 与文件名不匹配 | 确认图标名不含路径/扩展名，且 postinst 已执行 |
| 图标是占位符 | 图标缓存未刷新 | 手动运行 `sudo gtk-update-icon-cache -f /usr/share/icons/hicolor/` |
| 安装后菜单没出现 | 桌面数据库未更新 | 运行 `sudo update-desktop-database` |
| 以上都做了仍不显示 | 注销重新登录 | 系统会话才重新读取 desktop 文件 |

## 13. GitHub Release

创建 Release 并同时上传 RPM/DEB：

```bash
gh release create v0.0.12 \
  build/linux/x64/release/plume-pdf-0.0.12-10.fc44.x86_64.rpm \
  build/linux/x64/release/plume-pdf_0.0.12+10_amd64.deb \
  --title "v0.0.12" \
  --notes-file CHANGELOG.md
```

已有 Release 时使用：

```bash
gh release upload v0.0.12 \
  build/linux/x64/release/plume-pdf-0.0.12-10.fc44.x86_64.rpm \
  build/linux/x64/release/plume-pdf_0.0.12+10_amd64.deb \
  --clobber
```

## 14. 分发建议

- 直接把 `.deb` 作为 GitHub Release asset 上传
- Debian / Ubuntu 用户可直接安装
