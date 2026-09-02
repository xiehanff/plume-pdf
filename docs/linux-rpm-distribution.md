# Linux RPM Package Distribution

> 文档基线：Plume PDF `v0.1.0`，更新于 2026-09-02。

本文记录 Fedora/Linux RPM release 打包方式，以及 Hosted runner 上的特殊处理。

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

当前应用版本：

```text
0.1.0+24
```

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
- 安装包版本与 `pubspec.yaml` 一致

## 4. GitHub Hosted runner 特殊说明

Hosted Linux runner 使用 Ubuntu，因此 `patchelf` 通过 apt/dpkg 安装，而 `rpmbuild` 的 `BuildRequires` 只查看 RPM 自己的数据库。

当前脚本流程：

```text
确认 rpmbuild 命令存在
确认 patchelf 命令存在
→ rpmbuild --nodeps
```

`--nodeps` 只绕过“RPM 数据库看不到 apt 已安装 patchelf”的误判，并不是无条件忽略系统依赖。

## 5. CI / Release

普通 `main` push 会生成 DEB + RPM Actions Artifact。

正式发布时使用单一 release commit：

```text
version: 0.1.0+24
commit: release: v0.1.0
```

工作流会自动创建/校验 `v0.1.0` tag；RPM 与 DEB、Windows EXE、macOS DMG、Android arm64 APK 一起进入同一个 GitHub Release，不需要手动执行 `gh release upload`。

## 6. v0.1.0 发布验收

- Linux release bundle 构建成功
- DEB 打包成功
- RPM 打包成功
- Artifact 上传成功
- Release job 能下载两种 Linux 包
- GitHub Release 页面能看到 RPM 与 DEB
- RPM 在 Fedora 上可安装、启动、卸载

若 `rpmbuild` 报 `patchelf` BuildRequires 缺失，先检查脚本是否仍使用当前 `--nodeps` 兼容路径，不要改成在 Ubuntu 上尝试伪造 RPM package database。
