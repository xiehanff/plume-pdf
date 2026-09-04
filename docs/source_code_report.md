# Plume PDF 源码报告

> 文档基线：`main @ c19c2f82eec37940635168ab42cc731ab4f61ef6`，更新于 2026-09-04。
>
> 当前 `pubspec.yaml` 版本元数据仍为 `0.1.3+27`，最新已发布版本为 `v0.1.3`；本文同时记录 `v0.1.3` 之后已经进入 `main`、但尚未单独发版的 R5 / AI latest-wins / Viewer UI 调整。

## 1. 项目定位

`plume_pdf` 是独立 Flutter App，不是 Flutter Module。仓库当前包含 Windows、macOS、Linux、Android、iOS 工程；GitHub Release 当前发布 Windows/macOS/Linux/Android，iOS 保留源码支持但不进入现有 CI / Release 产物链路。

核心能力：

- PDF 阅读、目录、最近文件、阅读进度
- 单页 / 双页、缩放、适宽、背景主题
- 桌面拖拽打开 PDF、Windows/macOS 文件打开桥接
- AI 多轮对话、reasoning 流式展示与主动停止
- Viewer 级跨页区域框选
- PDF 文本 / 截图 / OCR 上下文提取
- Android/iOS 移动 Shell；Android 当前进入 CI / Release
- 移动端 WiFi 传书
- Linux DEB/RPM、Windows EXE、macOS DMG 自动打包

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

android/   Flutter Android 工程
ios/       Flutter iOS 工程
windows/   Windows Runner + OCR + Inno Setup
macos/     macOS Runner + Vision OCR + 文件打开桥接
linux/     Linux Runner + desktop entry + icons
scripts/   Linux/macOS/Windows 打包脚本
packaging/ RPM spec
packages/  本地 gpt_markdown fork
.github/workflows/
├─ mobile-ci.yml
└─ build-desktop-packages.yml
```

`docs/` 当前只保留仍有维护价值的发行说明、源码报告与 todo；旧的 AI Sidebar scroll-jump 专项文档已经从 `main` 删除，相关行为由源码注释与回归测试维护。

## 3. 平台启动与 Shell

`lib/main.dart` 只在 Windows/macOS/Linux 初始化 `window_manager`；Android/iOS 不走桌面窗口初始化。

```text
Android / iOS
    → MobileHomeView

Windows / macOS / Linux / Web fallback
    → HomeView
```

移动端没有复制一套业务 Controller，桌面与移动端共享：

```text
HomeController
PdfReaderState
PdfViewerController
AiSidebarController
AiAgentSession
PdfAiContextService
```

## 4. HomeController 与 Reader 状态

`HomeController` 是 Reader 模块的编排入口，具体职责通过 extension / service 分散：

- `home_controller_navigation.dart`：页码、缩放、单双页、适宽、目录跳转
- `home_controller_file_manager.dart`：文件、最近阅读、阅读进度、Outline
- `home_controller_ai_session.dart`：AI 动作、Chat、停止与 UI 状态编排

底层 AI transport、PDF context、OCR、封面、持久化继续由独立 service 负责。

### 4.1 页码与缩放事件源

当前页码和缩放不再共享同一 listener：

```text
PdfViewerParams.onPageChanged
    ↓
currentPage
selectedOutlineId
pageTextController
progress debounce

PdfViewerController listener
    ↓
zoom
```

页码使用 pdfrx 的 `onPageChanged` 语义；`PdfViewerController` listener 只同步 zoom，避免 transformation listener 与 layout 后页码计算互相覆盖。

### 4.2 文档切换与异步保护

当前 `main` 已有：

- page callback 携带 source `filePath`
- document callback 携带 source `filePath`
- Outline 使用 `loadId + filePath` 双重失效保护
- progress debounce 捕获触发时的 file/page 快照，执行前再次确认当前文件
- 打开不存在的 recent file 时，先验证 `File.exists()`，失败尝试不会推进 Reader / AI session generation

注意：在当前 `main` 中，`onViewerReady` / `onLoadError` 仍是直接 callback，并未像 page/document callback 一样携带 source `filePath`。因此源码阅读时不要把四类 Viewer callback 误认为已经完全统一。

### 4.3 当前桌面 Viewer 布局

最新 `main` 已把桌面 PDF 区域外层 padding 去掉：

```text
HomeView
  → LayoutBuilder
  → AiSelectablePdfViewer(pageMargin: 0)
```

`updateRenderAreaWidth(..., reserveScrollbarInset: false)` 不再为桌面滚动条预留额外宽度；`PdfViewerParams.pageDropShadow` 当前为 `null`，PDF 页面不绘制 drop shadow。

页码导航使用独立 `PageNavigator`，固定整体宽度 `176`、高度 `30`；页码输入区域会根据当前页/总页数字数在约 `48~60` px 之间自适应。

## 5. Reader 快捷键

当前 `ReaderShortcuts` 是 `StatefulWidget`。

普通快捷键仍由 `CallbackShortcuts` 负责：

- 打开文件
- 上一页 / 下一页
- 100% 实际尺寸
- 左侧目录栏
- 放大 / 缩小

Escape 单独走 `FocusManager.addEarlyKeyEventHandler`：

```text
KeyDown Escape
    ↓
ReaderFocusNode.hasFocus ?
    ↓ yes
onEscape()
    ↓
true  → handled
false → ignored
```

这样可以绕过 pdfrx descendant Focus 在 Linux/macOS 上提前消费 Escape 的情况，同时普通阅读状态又不会无条件吞掉外部控件的 Escape。

`dispose()` 会移除 early handler 并释放 Reader FocusNode。

## 6. AI 架构

当前调用链：

```text
HomeController
    ↓
HomeControllerAiSession
    ├───────────────┐
    ↓               ↓
AiAgentSession   PdfAiContextService
    │               │
    │               ├─ selection text
    │               ├─ page context
    │               ├─ screenshot
    │               └─ OCR fallback
    ↓
DeepSeekService
    ↓
OpenAI-compatible HTTP/SSE
```

当前生产 transport 仍只有 DeepSeek 的 direct HTTP/SSE 路径；`AiModelRegistry` / `AiModelConfig` 继续保留，用于后续多模型/provider 扩展，不应作为“未使用代码”删除。

## 7. AiAgentSession：Turn barrier、停止与 latest-wins

`AiAgentSession` 当前不仅保存 history，还负责 Turn 边界。

关键状态：

```text
_history
_generation
_activeStream
_turnTail
_latestTurn
```

### 7.1 Turn finalize barrier

每一轮真正发模型请求前，会等待上一轮完成 history commit / rollback：

```text
Turn A streaming
    ↓
Stop / done / error
    ↓
partial commit 或 rollback
    ↓
Turn A completion
────────────────────
    ↓
Turn B 才 snapshot history
    ↓
transport
```

因此 Stop 后 UI 可以立即恢复，但下一轮不会拿到“上一轮尚未收尾”的 history。

传给 transport 的 history 使用 `List.unmodifiable(_history)` snapshot，而不是共享可变 `_history` 引用。

### 7.2 `stopActiveStream()`

停止有两种情况：

- 已进入 SSE：取消当前 `StreamSubscription`
- 新 Turn 尚在等待 barrier：标记 `stoppedBeforeStart`，保证它不会真正发网络请求

已收到的部分正文/reasoning 可以保留；首 token 前停止时不保留空 assistant turn。

### 7.3 Tool Action latest-wins

`翻译 / 解释 / 深度理解` 采用 latest-wins。

每次新的 `runToolAction()` 进入时会先执行 `stopActiveStream()`：

```text
A 正在执行
↓
点击 B
→ stop A
→ B 等 A finalize

B 还没真正发网
↓
又点击 C
→ B stoppedBeforeStart
→ C 成为最新待执行 Tool
```

这样连续点击不会把已经失效的 Tool Action 全部排队真实发网。

Chat 的 Stop→立即再次 Send 仍使用同一 Turn barrier，但不会套用 Tool 的 latest-wins 入口。

### 7.4 `clear()`

新会话 / 文档切换 / Controller 销毁会：

```text
_history.clear()
_generation++
取消 active stream
使 pending Turn 失效
_turnTail = Future.value()
```

新 generation 不等待旧 transport 的异步 cancel 收尾。

## 8. 流式 preview 与 AiSidebar

### 8.1 preview 合并

SSE chunk 不直接逐 token 重建 UI。`AiAgentSession` 通过约 `40 ms` timer 合并 preview：

```text
高频 SSE chunks
   ↓
text/reasoning buffer
   ↓ ~40ms
onPreview
```

终态会取消 pending preview timer，避免完整结果已经落地后旧 preview 又回写。

### 8.2 AiSidebarController 单一 owner

生产环境中 `AiSidebarController` 只由 `HomeController` 创建和销毁。

`MobileAiView` 只展示，不再维护第二套 `Get.put` 创建路径；Debug Gallery 使用独立 tag。

Controller 的行为 callback 在构造时固定；`updateExternalState()` 只同步：

```text
PdfAiPanelState
documentPath
leftSidebarWidth
```

### 8.3 FollowTailScrollController

当用户仍跟随底部时，`correctForNewDimensions()` 使用 `correctPixels()` 并返回 `false`，让 viewport 在同一 frame 重新 layout，减少 streaming bubble 增长时的下一帧跳动。

用户主动上滚后，高频 streaming rebuild 可以延后；回到底部或进入 complete/error/stop 等终态时再 flush。

### 8.4 ChatInputBar

```text
loading = false
→ TextField enabled
→ Send

loading = true
→ TextField disabled
→ New Session disabled
→ Send 位置切换为 Stop
```

API Key 目前通过 `SharedPreferences` 本地缓存；这属于当前产品行为，本文不把它描述成 Keychain/Keystore 方案。

## 9. Viewer 级跨页 AI 框选

当前结构：

```text
PdfViewer
   ↓ viewerOverlayBuilder
PdfViewerAreaSelectionOverlay
   ↓ viewer-local Rect
controller.localToGlobal / globalToDocument
   ↓
pageLayouts intersect
   ↓
List<PdfAiSelectionRegion>
   ↓
PdfAiSelection
```

特性：

- Viewer 全局最多一个 committed selection
- 一个 selection 可跨连续多页
- page layout 纵向 gap 为 0
- 文本、截图、OCR 都围绕同一 selection 聚合
- Selection action toolbar 当前高度 `38`，宽度 `256`
- 正常情况下工具条按真实 viewport 选择选区上方/下方
- 当上下两侧都小于屏幕高度 `20%` 时，进入 center fallback；此时工具条的 X/Y 都围绕选区中心计算，而不是屏幕中心
- 移动端会避让右上 AI 模式控件，必要时切换上下方向

当前 `main` 的 `onAiSelectionChanged()` 仍会同步修改一部分 `PdfAiPanelState` 临时字段；因此源码层面还不能把 Selection lifecycle 描述成与 AI Turn 完全独立。本文只记录当前实际行为，不提前写入未合并分支的语义。

## 10. PdfAiContextService

负责：

- 单页 / 跨页 selection 文本提取
- selection screenshot
- 跨页截图纵向合并
- OCR fallback
- 页面上下文
- Chat document context

保留的边界检查包括：page bounds、rect clamp、空图像、render 失败、OCR fallback 等。

隐私边界：本机目录和文件大小不写入模型上下文；PDF 内容通过 `<document_context>` 等边界作为不可信文档数据处理。

## 11. DeepSeekService

当前只有一套直接 HTTP/SSE transport：

```text
AiAgentSession
    ↓
DeepSeekService.performStream / chatStream
    ↓
POST /v1/chat/completions
    ↓
SSE
    ├─ reasoning_content
    └─ content
```

当前保留：

- `deepseek-v4-flash-vision-exp`
- 普通 translate/explain/chat 的低 reasoning effort
- Deep Dive 较大的 completion budget
- 多轮 history
- 历史图片与 MIME 类型
- SSE JSON / HTTP status / response type 检查
- client / stream lifecycle 清理

视觉 fallback 只在 400/422 且错误明确表示 image/vision/media/multimodal 不支持时触发；认证、限流、网络错误不会自动重复一次纯文本请求。

## 12. WiFi 传书

`WifiTransferService` 只在移动端传书页面生命周期内启动 `HttpServer`：

- 默认端口 `8080`；被占用时回退随机端口
- 只接受 `.pdf`
- 单文件最大 `512 MB`
- 校验 `%PDF-` header
- 上传先写临时文件，再 rename commit
- 页面销毁时 `stop()` server
- 上传完成后调用 HomeController 打开新文件

当前实现没有 session/upload token，安全假设仍是“同一受信任局域网”。

## 13. 平台层

### macOS

- Finder / Dock / 默认打开方式文件路径接入
- Vision OCR
- DMG 打包

### Windows

- `Windows.Media.Ocr`
- `.pdf` 文件关联
- Inno Setup EXE installer
- 启动参数中的 PDF 路径由 `AppLaunchArgs` / executable arguments 接入

### Linux

- DEB / RPM
- desktop entry / hicolor icons

### Android

- 标准 Flutter Android Runner
- 仅 `arm64-v8a`
- CI 构建 arm64 debug APK 并检查最终 APK ABI
- Release workflow 构建 arm64 release APK
- 当前 release build 仍使用 debug signing config；正式商店分发前需要 production keystore

### iOS

- 工程仍保留
- 包含本地网络用途说明以支持 WiFi 传书
- 当前不进入 Mobile CI，也不生成 GitHub Release iOS 产物

## 14. CI / Release

### 14.1 Mobile CI

固定 Flutter：`3.41.9`，运行在 `ubuntu-latest`。

```text
flutter pub get
flutter test
flutter analyze --no-fatal-infos
flutter build apk --debug --target-platform android-arm64
verify APK native ABIs == arm64-v8a
```

当前不执行 iOS build。

### 14.2 Build Packages

普通 `main` push：

- Linux `.deb + .rpm`
- Windows `.exe`
- macOS `.dmg`

当前包版本元数据：

```text
version:      0.1.3+27
msix_version: 0.1.3.0
```

正式发布约定仍是：

```text
pubspec.yaml: version: X.Y.Z+N
head commit:  release: vX.Y.Z
```

`release_meta` 会从 `pubspec.yaml` 解析 tag，创建/校验 `vX.Y.Z`；发布模式额外构建 Android arm64 APK，并在 Linux/Windows/macOS/Android 全部成功后创建或更新 GitHub Release，Release Notes 从 `CHANGELOG.md` 对应版本章节提取。

当前 workflow 同时监听 `main` push 和 `v*` tag push。release commit 在 main run 中创建 tag 后，该 tag push 还会再触发一次 workflow；这是当前工作流的实际行为，阅读 Actions 历史时不要把第二次 tag run 误认为人工重复发布。

## 15. 当前 main 相对 v0.1.3 的重要未发版变化

`v0.1.3` 主要发布 Linux Escape/focus 修复。之后进入 `main` 的重要行为包括：

- Stop→立即再次 Send 的 history finalize barrier
- transport history immutable snapshot
- pending Turn 可在真正发网前停止
- Tool Action latest-wins，避免翻译/解释/深度理解连续触发时后台排队
- stale missing-PDF 尝试不推进 Reader/AI session lifecycle
- Selection toolbar 高度调整为 `38`
- center fallback 改为围绕 selection center 定位
- PDF page drop shadow 移除
- Desktop HomeView 去掉 PDF 外层 padding，`pageMargin: 0`
- PageNavigator 视觉和输入交互重构

因此调试当前 `main` 时，不应只依据 `CHANGELOG.md` 的 `v0.1.3` 发布章节判断功能状态。

## 16. Agent / 新成员阅读顺序

```text
lib/main.dart
  ↓
app/routes/app_pages.dart
  ↓
HomeView / MobileHomeView
  ↓
HomeController
  ↓
PdfReaderState
  ↓
HomeControllerNavigation / FileManager / AiSession
  ↓
AiSelectablePdfViewer
  ↓
PdfViewerAreaSelectionOverlay
  ↓
selection_toolbar_placement.dart
  ↓
AiSidebarController + FollowTailScrollController
  ↓
ChatInputBar
  ↓
AiAgentSession + PdfAiContextService
  ↓
DeepSeekService
```

桌面平台行为继续进入 `windows/` / `macos/` / `linux/`；Android Runner/ABI 进入 `android/`；iOS 当前只在本地开发或恢复发布时进入 `ios/`。
