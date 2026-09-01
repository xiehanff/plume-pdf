# Linux RPM Package Distribution

本文记录 Plume PDF 的 Fedora/Linux RPM release 打包方式。

## 1. 本地前置条件

Fedora：

```bash
sudo dnf install rpm-build patchelf
```

项目使用 FVM 锁定 Flutter 版本。

## 2. 生成 RPM

```bash
make package-rpm
```

脚本先构建 Linux Release，再使用 `packaging/plume-pdf.spec` 生成 RPM。

输出格式类似：

```text
build/linux/x64/release/plume-pdf-<version>-<build>.<dist>.x86_64.rpm
```

若已有最新 Release Bundle：

```bash
./scripts/build_linux_rpm.sh --skip-build
```

## 3. 安装测试

```bash
sudo dnf install ./build/linux/x64/release/*.rpm
```

卸载：

```bash
sudo dnf remove plume-pdf
```

验收：

- 应用菜单、图标正常
- 应用可启动并打开 PDF
- 桌面窗口控制正常
- 文件管理器“打开方式”链路正常

## 4. GitHub Actions 特殊说明

GitHub Hosted Linux runner 使用 Ubuntu，因此 `patchelf` 是通过 apt/dpkg 安装，而 `rpmbuild` 的 `BuildRequires` 只查看 RPM 自己的数据库。

当前脚本会：

```text
先检查 rpmbuild / patchelf 命令真实存在
→ rpmbuild --nodeps
```

`--nodeps` 只用于绕过“RPM 数据库看不到 apt 已安装 patchelf”的误判，并不是无条件忽略系统依赖。

## 5. CI / Release

普通 `main` push 会自动生成 DEB + RPM Actions Artifact。

明确 `v*` tag 时，RPM 会和 DEB、Windows EXE、macOS DMG、Android APK 一起进入 GitHub Release，不需要手动执行 `gh release upload`。

## 6. 当前验证状态

移动端合并前已在 Hosted runner 上重新验证 Linux Release、DEB、RPM、Artifact 上传整条链路通过。
