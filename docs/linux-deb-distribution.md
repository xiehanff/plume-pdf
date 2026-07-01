# Linux Debian Package Distribution

项目路径：`/home/hax/Documents/plume-pdf`

这份文档只记录两件事：

- 如何生成 Linux `release` bundle
- 如何打包成 `.deb`

## 1. 前置条件

- 使用项目固定 Flutter 版本：`fvm`
- 本机已安装 `dpkg-deb`

## 2. 先生成 Release Bundle

```bash
fvm flutter build linux --release --verbose
```

生成结果在：

```text
build/linux/x64/release/bundle/
```

## 3. 组装 Debian 包目录

```bash
pkg_root=/tmp/opencode/plume_pdf_deb_root
rm -rf "$pkg_root"
mkdir -p "$pkg_root/DEBIAN"
mkdir -p "$pkg_root/opt"
mkdir -p "$pkg_root/usr/share/applications"
mkdir -p "$pkg_root/usr/share/icons"
cp -a build/linux/x64/release/bundle "$pkg_root/opt/plume_pdf"
cp -a linux/icons/hicolor "$pkg_root/usr/share/icons/"
```

## 4. 写入 control 文件

```bash
cat > "$pkg_root/DEBIAN/control" <<'EOF'
Package: plume-pdf
Version: 0.0.9+7
Section: utils
Priority: optional
Architecture: amd64
Maintainer: xiehan <noreply@example.com>
Depends: libc6, libgtk-3-0, libglib2.0-0, libstdc++6
Description: Plume PDF
 A Flutter PDF reader packaged for Linux.
EOF
```

## 5. 安装桌面入口

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

## 6. 修复图标文件名（重要）

`linux/icons/hicolor/*/apps/` 下图标文件名为 `com.example.mint_pdf.png`（项目重命名前的遗留），但 desktop entry 引用的是 `Icon=com.example.plume_pdf`。名称不匹配会导致安装后图标不显示。

打包前修正：

```bash
for dir in "$pkg_root/usr/share/icons/"*/*/apps/; do
  if [ -f "${dir}com.example.mint_pdf.png" ]; then
    mv "${dir}com.example.mint_pdf.png" "${dir}com.example.plume_pdf.png"
  fi
done
```

同时建议将源文件 `linux/icons/hicolor/*/apps/com.example.mint_pdf.png` 批量重命名为 `com.example.plume_pdf.png`，从源头解决。

## 7. postinst 脚本 — 安装后刷新图标缓存

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

## 8. 生成 `.deb`

```bash
dpkg-deb --build --root-owner-group "$pkg_root" /tmp/opencode/plume-pdf_0.0.9+7_amd64.deb
```

## 9. 安装测试

```bash
sudo apt install /tmp/opencode/plume-pdf_0.0.9+7_amd64.deb
# 如果缺少依赖
sudo apt install -f
```

安装后可在应用菜单中搜索 "Plume PDF"，图标应正常显示。

## 10. 输出位置

```text
/tmp/opencode/plume-pdf_0.0.9+7_amd64.deb
```

## 11. 图标不显示的排查

| 问题 | 原因 | 解决 |
|---|---|---|
| 菜单中无图标 | desktop entry 中 `Icon=` 与文件名不匹配 | 确认图标名不含路径/扩展名，且 postinst 已执行 |
| 图标是占位符 | 图标缓存未刷新 | 手动运行 `sudo gtk-update-icon-cache -f /usr/share/icons/hicolor/` |
| 安装后菜单没出现 | 桌面数据库未更新 | 运行 `sudo update-desktop-database` |
| 以上都做了仍不显示 | 注销重新登录 | 系统会话才重新读取 desktop 文件 |

## 12. 分发建议

- 直接把 `.deb` 作为 GitHub Release asset 上传
- Debian / Ubuntu 用户可直接安装
