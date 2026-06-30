# Linux Debian Package Distribution

项目路径：`/home/hax/Documents/github/mint_pdf`

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

## 6. 生成 `.deb`

```bash
dpkg-deb --build --root-owner-group "$pkg_root" /tmp/opencode/plume-pdf_0.0.9+7_amd64.deb
```

## 7. 安装测试

```bash
sudo apt install ./plume-pdf_0.0.9+7_amd64.deb
```

## 8. 输出位置

```text
/tmp/opencode/plume-pdf_0.0.9+7_amd64.deb
```

## 9. 分发建议

- 直接把 `.deb` 作为 GitHub Release asset 上传
- Debian / Ubuntu 用户可直接安装
