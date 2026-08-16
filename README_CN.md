# Plume PDF

[English](./README.md) | 中文

基于 Flutter + PDFium 的桌面高性能 PDF 阅读器，具有 DeepSeek / SiliconFlow AI 辅助能力。

## 功能

- 本地 PDF 打开与最近文件记录（田字格网格展示）
- 支持从 Finder 双击 PDF、拖到 Dock 图标、或拖到应用窗口内直接打开文件
- 支持 Windows "打开方式" / 双击 `.pdf` 后直接唤起并打开文件
- 提供 Fedora 系 `.rpm` 与 Debian/Ubuntu 系 `.deb` release 安装包
- 目录侧边栏与章节跳转（同页多级目录点击时保持手动选中项）
- 上一页 / 下一页 / 页码跳转
- 放大 / 缩小 / 适宽 / 恢复 `100%`
- 单页 / 双页阅读模式
- AI 框选模式
- 框选后快捷操作：`翻译`、`解释`（附带整页上下文）
- 右侧 AI 侧边栏：支持切换 DeepSeek / SiliconFlow provider，分别配置 API Key，展示返回内容并支持多轮对话追问
- Markdown 渲染（gpt_markdown）+ 代码块语法高亮（atom-one-dark）
- Windows / Markdown / 普通正文统一回退到工程内置的 `PingFangSC`，代码块继续使用 `JetBrainsMono`
- 支持视觉理解模型时，AI 框选优先走截图发云端模型理解；失败后再回退到本地 OCR / 文本提取
- 不支持视觉理解的模型不会走截图链路，避免无意义渲染
- 阅读背景主题切换：`默认` / `阴天` / `羊皮纸` / `护眼绿`

## 平台说明

| 平台 | 状态 | 说明 |
|---|---|---|
| macOS | 可用 | 保留原生 Vision OCR，实现 PDF 默认打开方式注册、Dock/Finder 打开与窗口拖拽打开 |
| Windows | 可用 | 已补齐原生 OCR、快捷键、窗口标题、圆角图标、`.pdf` 打开方式注册 |
| Linux | 可用 | 提供 Fedora 系发行版 `.rpm` 包，支持原生标题栏与图标显示 |

## 开发

本项目使用 [fvm](https://fvm.app/) 管理 Flutter 版本，所有 `flutter` / `dart` 命令必须通过 `fvm` 前缀执行，禁止直接使用全局命令。

```bash
# 首次克隆后
fvm install                       # 安装 .fvmrc 中锁定的 Flutter 版本
fvm flutter pub get               # 安装依赖

# 日常开发
fvm dart analyze lib/             # 代码分析
fvm flutter run -d windows         # 运行 Windows
fvm flutter run -d macos           # 运行 macOS
fvm flutter run -d linux           # 运行 Linux
fvm flutter build windows          # 构建 Windows
fvm flutter build macos            # 构建 macOS
fvm flutter build linux            # 构建 Linux
powershell -File .\make.ps1 build-msix-windows  # 生成 Windows MSIX
.\make.cmd package-windows         # 生成 Windows Release 和安装包
fvm flutter build linux --release --verbose  # 构建 Linux Release 包
fvm flutter clean                  # 清理构建产物
fvm flutter pub upgrade            # 升级依赖
```

## Windows 分发

- MSIX 包：`powershell -File .\make.ps1 build-msix-windows`
- Inno Setup 安装包：`.\make.cmd package-windows`

相关文档：

- [Windows 安装包生成与分发](./docs/windows-installer-distribution.md)

## Linux 分发

- RPM 安装包：`plume-pdf-0.0.13-11.fc44.x86_64.rpm`
- 适用于 Fedora 系发行版
- DEB 安装包：`plume-pdf_0.0.13+11_amd64.deb`
- GitHub Release `v0.0.13` 中可直接下载附带的 `.rpm` 与 `.deb` 文件
- 生成 RPM：`make package-rpm`
- 生成 DEB：`make package-deb`
- RPM 打包说明：[Linux RPM 包分发说明](./docs/linux-rpm-distribution.md)
- Debian/Ubuntu 分发说明：[Linux Debian 包分发说明](./docs/linux-deb-distribution.md)

## 技术说明

- PDF 渲染与交互基于 `pdfrx`，底层依赖 PDFium
- 图片型 PDF 的文字识别走原生 OCR：macOS 用 Vision，Windows 用 `Windows.Media.Ocr`
- AI 请求支持 DeepSeek 与 SiliconFlow 聊天补全接口
- SiliconFlow 当前接入模型为 `Qwen/Qwen3-VL-30B-A3B-Instruct`
- 模型能力配置通过 `assets/config/ai_models.json` 预置，按 `supportsVision` 决定是否启用截图理解链路
- Markdown 渲染使用 gpt_markdown（本地 fork 在 `packages/gpt_markdown`）
- `gpt_markdown` 和应用本体都内置了 `PingFangSC` 字体资产，避免依赖本机外部字体路径
- 代码高亮使用 flutter_highlight（atom-one-dark 主题）
- macOS 文件打开链路额外接入原生 openFiles 回调，用于接收 Finder / Dock 传入的 PDF 路径
- Windows 构建额外使用 [`Directory.Build.props`](./Directory.Build.props) 关闭 `TrackFileAccess`，防止 `MSBuild/Tracker.exe` 卡住
- Windows 发布脚本在 [`scripts/build_windows_msix.ps1`](./scripts/build_windows_msix.ps1)，会生成圆角 Windows 图标并打包 `msix`
- Windows 安装包脚本在 [`windows/installer/build_installer.ps1`](./windows/installer/build_installer.ps1)，会把 Release 目录打成 Inno Setup 安装包，并自动创建桌面与开始菜单快捷方式

## 主要依赖

- `desktop_drop`：桌面端窗口拖拽打开文件
- `get`：路由与状态管理
- `pdfrx`：PDF 渲染与阅读器控制
- `gpt_markdown`：Markdown 渲染（本地 fork）
- `flutter_highlight` + `highlight`：代码语法高亮
- `file_selector`：原生文件选择对话框
- `hugeicons`：工具栏与状态图标
- `http`：DeepSeek API 请求
- `shared_preferences`：最近文件持久化
