# Plume PDF

[English](./README.md) | 中文

**当前版本：v0.1.2**

Plume PDF 是一个基于 Flutter + PDFium（`pdfrx`）的跨平台 PDF 阅读器，并集成 DeepSeek AI 辅助阅读。桌面端与移动端共用阅读状态/控制层，只在 UI Shell 和导航交互上按平台拆分。

## v0.1.2 重点更新

- AI 流式输出期间，原“发送”按钮不再处于不可点击状态，而是切换为可点击的“停止生成”按钮。
- 点击停止会真正取消当前 `StreamSubscription`，让 DeepSeek SSE 立即停止继续消费，而不是只在 UI 层忽略后续 token。
- 已经收到的部分正文与 reasoning 会保留，停止后直接作为本轮部分回复收尾。
- 第一个 token 尚未返回时停止，会移除空的 loading 占位，不留下空白 AI 消息。
- 如果仍处在 PDF / 文档上下文准备阶段，则复用现有 action generation 保护让本轮请求失效，不继续进入模型 stream。
- 新建 AI 会话或销毁 `HomeController` 时也会主动取消当前 stream。
- 新增停止按钮、底层 subscription cancel、部分回答保留与空 loading 清理回归测试。

`v0.1.1` 仍是较大的阅读器/AI 基线版本：Android 移动 Shell、Viewer 级跨页 AI 框选、流式多轮对话、Reader 状态收敛、唯一 `AiSidebarController` owner 与单一 DeepSeek HTTP/SSE transport 都已在该版本形成稳定基础。

完整发布说明见 [CHANGELOG.md](./CHANGELOG.md)。

## 功能

### 阅读

- 打开本地 PDF，并保存最近文件与阅读进度
- PDF 目录导航
- 上一页 / 下一页 / 页码跳转
- 放大 / 缩小 / 适宽 / 恢复 `100%`
- 单页 / 双页阅读模式
- 阅读背景主题：`默认` / `阴天` / `羊皮纸` / `护眼绿`
- PDF 连续排版时页面上下间距为 0

### AI 辅助阅读

- 配置 DeepSeek API Key，支持流式多轮对话
- 流式生成期间可直接点击发送位的停止按钮；停止后保留已经收到的部分回复
- AI 区域框选动作：`翻译`、`解释`、`深度理解`
- 框选属于整个 PDF Viewer，而不是某一页，因此一个框选可以连续跨越多页
- 全局任何时刻最多存在一个框选框和一组动作按钮
- 跨页文字按页顺序提取并合并；截图/OCR 回退会裁剪每个命中的页面区域并合成为一次 AI 上下文
- 视觉请求优先使用截图理解；本地 OCR / PDF 文本提取继续作为上下文回退链路
- PDF 提取内容按“不可信文档数据”处理；不会把本机文件目录和文件大小发送给模型
- 流式返回中 reasoning 与正式正文分离展示
- `FollowTailScrollController` 使用同帧 viewport correction，避免贴底输出时画面晚一帧跳动
- 用户上滚阅读历史时，AI Sidebar 会延后高频昂贵 rebuild；回到底部或进入完成/错误/停止终态后统一 flush
- Markdown 使用本地 fork 的 `gpt_markdown`，代码块支持语法高亮

### 桌面端

- macOS：Finder / Dock / 窗口拖拽打开 PDF，原生 Vision OCR
- Windows：`.pdf` 文件关联、原生 OCR、快捷键、Inno Setup 安装包
- Linux：提供 `.deb` 与 `.rpm` 包

### 移动端

- 已加入标准 Flutter Android / iOS 工程
- Android 仅支持 ARMv8-A / `arm64-v8a`
- 使用独立 `MobileHomeView`，桌面 `HomeView` 保持桌面交互结构
- 阅读区完整处理顶部/底部 SafeArea，并提供固定移动端工具栏
- 目录、AI 使用全屏移动路由，但继续复用同一套 `HomeController`、`PdfReaderState`、`PdfViewerController`
- 移动 AI 输入区域在系统底部安全区基础上额外保留 20 px
- WiFi 传书：打开传书页面期间，在受信任的同一局域网中临时启动 HTTP 服务；电脑可上传经过扩展名、大小和 PDF 文件头校验的文档，上传成功后手机自动打开

## 平台状态

| 平台 | 状态 | 发布方式 |
|---|---|---|
| macOS | 可用 | DMG；原生 Vision OCR |
| Windows | 可用 | Inno Setup EXE；原生 OCR 与 `.pdf` 文件关联 |
| Linux | 可用 | DEB + RPM |
| Android | 可用 | `arm64-v8a` release APK |
| iOS | 保留源码支持 / 当前不发布 | 仓库保留标准 iOS 工程，但当前 CI 与 GitHub Release 有意不构建、不发布 iOS App |

> Android 当前 `release` buildType 仍使用仓库中的 debug signing 配置。该 APK 适合自测/自托管分发；正式上架 Play Store 或生产分发前必须接入 production keystore。

## 开发

项目使用 [FVM](https://fvm.app/) 管理 Flutter，版本锁定在 `.fvmrc`。

```bash
fvm install
fvm flutter pub get
fvm flutter test
fvm flutter analyze --no-fatal-infos

# 桌面端
fvm flutter run -d windows
fvm flutter run -d macos
fvm flutter run -d linux

# Android
fvm flutter run -d android
fvm flutter build apk --debug --target-platform android-arm64

# iOS 仍可在需要时本地开发
fvm flutter run -d ios
```

## CI 与发布

### Mobile CI

当前运行在 Ubuntu，验证：

```text
flutter pub get
flutter test
flutter analyze --no-fatal-infos
flutter build apk --debug --target-platform android-arm64
校验 APK 原生库只包含 arm64-v8a
```

当前明确**不执行 iOS build**，避免在暂不发布 iOS App 的阶段占用额外 CI 时间。

### Build Packages

普通 `main` push 会构建并上传桌面 Actions Artifact：

- Linux：DEB + RPM
- Windows：EXE installer
- macOS：DMG

当 `main` 出现提交消息严格为 `release: v<version>` 的发布提交时，工作流会自动识别版本、创建/校验对应 tag，额外构建 Android arm64 release APK，等待所有发布 job 成功后创建 GitHub Release 并上传所有安装包。

v0.1.2 预期发布资产：

```text
Linux   .deb + .rpm
Windows .exe
macOS   .dmg
Android plume-pdf-android-arm64-v8a-v0.1.2.apk
```

GitHub Release 文案会自动从 `CHANGELOG.md` 中同版本章节提取。

## 分发文档

- [Windows 安装包生成与分发](./docs/windows-installer-distribution.md)
- [Linux Debian 包分发说明](./docs/linux-deb-distribution.md)
- [Linux RPM 包分发说明](./docs/linux-rpm-distribution.md)

## 架构说明

```text
HomeController
├─ 阅读 / 文件 / 导航编排
├─ HomeControllerAiSession
│    ├─ AiAgentSession
│    └─ PdfAiContextService
└─ AiSidebarController
     └─ FollowTailScrollController

AiAgentSession
    ↓
DeepSeekService
    ↓
OpenAI-compatible HTTP/SSE
```

关键点：

- PDF 渲染：`pdfrx` / PDFium
- 路由与状态：GetX
- 共用阅读状态：`HomeController` + `PdfReaderState` + `PdfViewerController`
- 页码唯一事件源：`PdfViewerParams.onPageChanged`；Controller listener 只同步 zoom
- 桌面 Shell：`HomeView`
- 移动 Shell：`MobileHomeView`，目录 / AI / WiFi 传书使用独立全屏路由
- AI Sidebar 生命周期：唯一 `AiSidebarController` 由 `HomeController` 管理
- AI 会话、历史、流式累积与当前 stream 取消：`AiAgentSession`
- PDF 文本 / 截图 / OCR 上下文：`PdfAiContextService`
- 当前 AI transport：`DeepSeekService` 直接 HTTP/SSE
- 为后续多模型接入保留 `AiModelRegistry` / `AiModelConfig`
- Viewer 级跨页框选：`PdfViewerAreaSelectionOverlay`
- 局域网传书：`WifiTransferService`

更详细的源码结构见 [docs/source_code_report.md](./docs/source_code_report.md)。

## 主要依赖

- `get`：路由与状态管理
- `pdfrx`：PDF 渲染与阅读器控制
- `gpt_markdown`：Markdown 渲染（本地 fork）
- `flutter_highlight` + `highlight`：代码语法高亮
- `file_selector`：原生文件选择器
- `desktop_drop`：桌面窗口拖拽打开文件
- `http`：DeepSeek HTTP/SSE transport 与其他 HTTP 工具
- `shared_preferences`：最近文件 / 阅读设置持久化
- `path_provider`：应用目录，包括移动端 WiFi 传书文件存储
