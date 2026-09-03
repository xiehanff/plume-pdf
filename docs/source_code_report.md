# Plume PDF 源码报告

> 文档基线：`v0.1.2`，更新于 2026-09-03。本文描述当前 `main` 的实际结构。

## 1. 项目定位

`plume_pdf` 是独立 Flutter App，不是 Flutter Module。当前仓库包含 Windows、macOS、Linux、Android、iOS 工程；正式 GitHub Release 当前发布 Windows/macOS/Linux/Android，iOS 保留源码支持但暂不进入 CI 与发布链路。

核心能力：

- PDF 阅读、目录、最近文件、阅读进度
- 单页 / 双页、缩放、适宽、背景主题
- AI 多轮对话与 reasoning 流式展示
- AI 流式生成主动停止与底层 SSE subscription 取消
- Viewer 级跨页区域框选
- PDF 文本 / 截图 / OCR 上下文提取
- 移动端 WiFi 传书
- 桌面多平台安装包自动打包

## 2. 顶层结构

```text
lib/
├─ main.dart
└─ app/
   ├─ routes/
   ├─ theme/
   ├─ services/
   └─ modules/home/
      ├─ bindings/
      ├─ controllers/
      ├─ models/
      ├─ services/
      └─ views/

android/   标准 Flutter Android 工程
ios/       标准 Flutter iOS 工程
windows/   Windows Runner + OCR + Installer
macos/     macOS Runner + Vision OCR + 文件打开桥接
linux/     Linux Runner + desktop entry + icons
scripts/   桌面打包脚本
packaging/ RPM spec
packages/  本地 gpt_markdown fork
.github/workflows/
├─ mobile-ci.yml
└─ build-desktop-packages.yml
```

## 3. 平台启动与 Shell

`lib/main.dart` 只在 Windows/macOS/Linux 初始化 `window_manager`。Android/iOS 不进入桌面窗口初始化流程。

```text
Android / iOS
    → MobileHomeView

Windows / macOS / Linux / Web fallback
    → HomeView
```

移动适配没有复制业务 Controller，而是共享：

```text
HomeController
PdfReaderState
PdfViewerController
AiSidebarController
AiAgentSession
PdfAiContextService
```

## 4. HomeController 与 Reader 状态

`HomeController` 是阅读模块的编排入口，职责分散在 extension / service 中，不承担所有底层实现。

主要职责：

- 文件打开、最近文件、阅读进度
- 页码、缩放、单双页、适宽
- Outline 加载与跳转
- AI 动作 / 对话 / 停止编排
- `PdfViewerController` 与 AI Sidebar 生命周期

### 4.1 页码与缩放事件源

当前不再让两个不同事件源同时写 `currentPage`。

```text
PdfViewerParams.onPageChanged
    ↓
currentPage / selectedOutlineId / pageText / progress save

PdfViewerController listener
    ↓
zoom
```

页码使用 pdfrx 明确的 `onPageChanged` 语义；Controller listener 只负责 zoom，避免 transformation listener 与 layout 后页码计算存在时序差异。

### 4.2 文档切换竞态保护

Viewer/document/outline 回调都绑定来源文档：

- page callback 携带 source `filePath`
- document callback 校验 source `filePath`
- outline 使用 `loadId + filePath` 双重失效保护
- recent-file progress debounce 捕获触发时的 file/page 快照，并在执行前确认仍是同一文件

因此快速切换 PDF 时，旧文档的异步结果不能覆盖新文档状态。

## 5. AI 架构

当前调用链：

```text
HomeController
    ↓
HomeControllerAiSession
    ├───────────────┐
    ↓               ↓
AiAgentSession   PdfAiContextService
    │               │
    │               ├─ 选区文本
    │               ├─ 跨页区域
    │               ├─ PDF 页面全文
    │               ├─ 截图裁剪
    │               └─ OCR fallback
    ↓
DeepSeekService
    ↓
OpenAI-compatible HTTP/SSE
```

### 5.1 AiAgentSession

负责：

- 会话 history
- tool action / chat
- stream accumulation
- reasoning accumulation
- preview 合并
- response parsing
- history commit / rollback
- request generation / stale stream 防护
- active `StreamSubscription` 生命周期
- 用户主动停止当前 AI stream

v0.1.2 的停止链路：

```text
ChatInputBar stop
    ↓
AiSidebarController.onStopChat
    ↓
HomeController.stopAiResponse
    ↓
AiAgentSession.stopActiveStream
    ↓
StreamSubscription.cancel
    ↓
DeepSeekService async stream 退出
    ↓
HTTP client finally / close
```

停止后不再消费后续 SSE 增量；已经收到的部分正文/reasoning 保留。若在第一个 token 前停止，则回滚悬空 user/history 或删除空 loading 占位。若还在文档上下文准备阶段，则通过 `_aiActionId` 让请求失效，从而不进入实际模型 stream。

### 5.2 PdfAiContextService

负责：

- 单页 / 跨页 selection 文本提取
- 页面上下文
- selection 截图
- 跨页截图纵向合并
- OCR fallback
- 文档上下文边界处理

隐私边界：本机目录和文件大小不发送给模型；PDF 内容通过 `<document_context>` 等边界作为不可信数据处理。

### 5.3 DeepSeekService

当前只有一套直接 HTTP/SSE transport：

```text
AiAgentSession
    ↓
DeepSeekService.performStream / chatStream
    ↓
POST /v1/chat/completions
    ↓
SSE LineSplitter
    ├─ reasoning_content
    └─ content
```

保留：

- `deepseek-v4-flash-vision-exp`
- 日常动作 `reasoning_effort=low`
- 深度理解 32768 completion token budget
- 多轮历史
- 历史图片 / MIME 类型
- SSE JSON 类型与状态码边界检查
- transport/client 生命周期清理

视觉回退只在 HTTP 400/422 且错误明确表示 image / vision / media / multimodal 能力拒绝时成立。401、限流、网络错误不会重复发送纯文本请求。

`AiModelRegistry` / `AiModelConfig` 继续保留，为后续多模型/provider 扩展提供配置层，但当前生产 transport 仍是 DeepSeek。

## 6. AiSidebar 生命周期与流式 UI

### 6.1 单一 Controller owner

生产环境只有 `HomeController` 创建和销毁 `AiSidebarController`：

```text
HomeController.onInit
    → register AiSidebarController

HomeController.onClose
    → stop active AI stream
    → delete AiSidebarController
```

`MobileAiView` 只负责展示，不再自行 `Get.put`。

Debug Gallery 使用独立 tag，避免预览页面删除 Home 正在使用的 Controller。

### 6.2 Streaming rebuild suppression

旧的 `StreamingAiSidebarController` 已删除，其职责并入 `AiSidebarController`。

当模型仍在输出、用户主动离开底部阅读历史时：

- 高频 preview 状态继续更新
- 昂贵 UI rebuild 延后
- 回到底部后 flush
- complete/error/stop 等终态立即刷新

### 6.3 FollowTailScrollController

`FollowTailScrollPosition.correctForNewDimensions(...)` 在内容增长时通过 `correctPixels()` 修正位置，并返回 `false` 让 viewport 在同一 frame 重新 layout，避免“数值已贴底但画面下一帧才跳”的闪烁。

该行为有 render-level 回归测试，不应在 Flutter 升级时随意删除。

### 6.4 ChatInputBar loading / stop 状态

```text
loading = false
→ 输入可编辑
→ send 可点击

loading = true
→ 输入禁用
→ new session 禁用
→ send 位置切换为 stop，仍可点击
```

停止后 `aiPanelState.loading` 同步置为 false，按钮立即恢复普通发送状态。AI 消息中已经收到的内容保留；完全空的 loading message 被移除。

## 7. Viewer 级跨页 AI 框选

当前结构：

```text
PdfViewer
   ↓ viewerOverlayBuilder
PdfViewerAreaSelectionOverlay
   ↓
viewer-local Rect
   ↓ globalToDocument
PDF document Rect
   ↓ intersect pageLayouts
List<PdfAiSelectionRegion>
   ↓
PdfAiSelection
```

特性：

- 全局最多一个 selection
- 一个 selection 可跨连续多页
- 页面纵向 gap 为 0
- selection 映射为多个 page region
- 文本、截图、OCR 都围绕同一个 selection 聚合

工具条按真实 viewport 空间布局，不依赖“当前页坐标”；上下空间都不足屏幕高度 20% 时回到选区垂直中心，并保持 viewport 水平居中。

## 8. WiFi 传书

`WifiTransferService` 只在移动传书页面生命周期内启动 `HttpServer`：

- 默认端口 8080；占用时回退随机端口
- 只接受 `.pdf`
- 最大 512 MB
- 校验 `%PDF-` header
- 上传先写临时文件，再 rename commit
- 页面销毁时停止 server

当前安全假设仍是“受信任同一局域网”。公开分发前建议加入随机 session/upload token。

## 9. 平台层

### macOS

- Finder / Dock / 默认打开方式文件路径接入
- Vision OCR
- DMG 打包

### Windows

- `Windows.Media.Ocr`
- `.pdf` 文件关联
- Inno Setup EXE installer

### Linux

- DEB / RPM
- desktop entry / icons

### Android

- 标准 Flutter Android Runner
- `arm64-v8a` only
- Mobile CI 构建 arm64 debug APK 并检查 ABI
- 正式 tag/release 构建 arm64 release APK
- 当前 release 使用 debug signing，生产分发前需要 production keystore

### iOS

- 标准 Flutter iOS Runner 仍保留
- 本地网络用途说明用于 WiFi 传书
- 当前不进入 Mobile CI，也不生成 GitHub Release iOS 产物
- 未来恢复发布时再补生产签名 / IPA 流程

## 10. CI / Release

### Mobile CI

当前运行在 `ubuntu-latest`：

```text
flutter pub get
flutter test
flutter analyze --no-fatal-infos
flutter build apk --debug --target-platform android-arm64
verify native ABIs == arm64-v8a
```

不执行 iOS build。

### Build Packages

普通 `main` push：

- Linux DEB + RPM
- Windows EXE
- macOS DMG

v0.1.2 发布提交：

```text
pubspec.yaml version: 0.1.2+26
commit message: release: v0.1.2
```

`release_meta` 会读取版本并创建/校验 `v0.1.2` tag。发布模式额外构建 Android arm64 APK，并在 Linux/Windows/macOS/Android 全部成功后创建 GitHub Release；Release Notes 自动取自 `CHANGELOG.md` 的 `0.1.2` 章节。

## 11. 结构收敛结果

以 `release: v0.0.22` 的 `14685f5` 为基线，到第四轮重构合并完成的 `42b17e9`：

```text
生产 Dart 代码 lib/**   -392 行
测试 test/**            +55 行
依赖 pubspec*           -138 行
CI                       -3 行
全仓库净变化            -478 行
```

重点不是单纯缩行，而是删除重复机制：

- 三套快捷键输入路径 → 一套 `CallbackShortcuts + Focus`
- 独立 Streaming AI Controller → 合并到 `AiSidebarController`
- Page 多状态写入口 → `onPageChanged` 单一页码事件源
- Desktop/Mobile AI Controller 双创建路径 → `HomeController` 单一 owner
- Genkit + direct HTTP 双 transport → 单 HTTP/SSE transport

v0.1.2 在这条单一 AI 会话链上继续补齐“用户主动取消”的完整资源生命周期，而没有再增加第二套 stop/cancel 状态源。

## 12. Agent 阅读顺序

```text
lib/main.dart
  ↓
app/routes/app_pages.dart
  ↓
HomeView / MobileHomeView
  ↓
HomeController
  ↓
PdfReaderState + HomeControllerNavigation/FileManager/AiSession
  ↓
AiSelectablePdfViewer
  ↓
PdfViewerAreaSelectionOverlay
  ↓
AiSidebarController + FollowTailScrollController
  ↓
ChatInputBar
  ↓
AiAgentSession + PdfAiContextService
  ↓
DeepSeekService
```

桌面平台行为继续进入 `windows/` / `macos/` / `linux/`；Android Runner/权限进入 `android/`；iOS 当前仅在需要本地开发时进入 `ios/`。
