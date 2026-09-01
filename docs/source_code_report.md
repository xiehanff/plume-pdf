# Plume PDF 源码报告

> 更新于 2026-09-01。本文描述当前 `main`/移动端合并后的目标结构，不再以早期“macOS MVP”视角描述项目。

## 1. 项目定位

`plume_pdf` 是独立 Flutter App，不是 Flutter Module。当前目标平台包括：

- Windows
- macOS
- Linux
- Android
- iOS

核心能力包括 PDF 阅读、目录/最近文件、阅读进度、AI 多轮对话、Viewer 级跨页区域框选、文本/截图/OCR 上下文提取，以及移动端 WiFi 传书。

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
.github/workflows/
├─ mobile-ci.yml
└─ build-desktop-packages.yml
```

## 3. 平台启动隔离

`lib/main.dart` 只在 Windows/macOS/Linux 初始化 `window_manager`。Android/iOS 不进入桌面窗口初始化流程。

`app/routes/app_pages.dart` 根据运行平台决定 Home Shell：

```text
Android / iOS
    → MobileHomeView

Windows / macOS / Linux / Web fallback
    → HomeView
```

这意味着移动端适配没有复制第二套业务 controller，而是只拆 UI Shell 和导航表现。

## 4. Home 模块

### HomeController

`HomeController` 仍是阅读模块编排入口，但职责已经拆到多个文件/服务：

- 文件打开、最近文件与持久化
- 页码、缩放、单双页、适宽
- Outline 跳转
- AI 动作/对话编排
- `PdfViewerController` 生命周期

移动端和桌面端共用：

```text
HomeController
PdfReaderState
PdfViewerController
AiSidebarController / StreamingAiSidebarController
AiAgentSession
PdfAiContextService
```

### 桌面 Shell

`home_view.dart` 保留桌面三栏/工具栏结构，负责桌面拖拽、标题栏、左右 Sidebar 和状态栏。

### 移动 Shell

`mobile_home_view.dart` 使用移动端布局：

- PDF 内容避开顶部 SafeArea
- 固定移动工具栏占用底部布局空间
- 底部系统安全区继续保留
- Outline、AI、WiFi 传书进入独立全屏路由

相关页面：

- `mobile_outline_view.dart`
- `mobile_ai_view.dart`
- `mobile_wifi_transfer_view.dart`
- `mobile_reader_floating_toolbar.dart`

## 5. AI 架构

当前核心调用链：

```text
HomeController
    ↓ 编排 / state
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
DeepSeekService / Genkit
```

### AiAgentSession

负责：

- 会话 history
- tool action / chat
- stream accumulation
- reasoning accumulation
- preview 合并
- response parsing
- history commit / rollback
- request generation / stale stream 防护

### PdfAiContextService

负责：

- 单页/跨页 selection 文本提取
- 页面上下文
- selection 截图
- 跨页截图纵向合并
- OCR fallback
- 文档上下文边界处理

隐私边界：本机目录和文件大小不发送给 DeepSeek；PDF 文本按不可信文档内容处理。

## 6. Viewer 级跨页 AI 框选

旧结构是 `pageOverlaysBuilder` 每页维护一份 Stateful selection overlay，导致不同页可以同时残留选区。

当前结构改为：

```text
PdfViewer
   ↓ viewerOverlayBuilder
PdfViewerAreaSelectionOverlay  ← 全局唯一
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
- 可跨多页
- PDF 页纵向 gap 为 0
- selection 结束后映射为多个 page region
- AI 文本/截图按同一个 selection 处理

### 工具条定位

`selection_toolbar_placement.dart` 使用屏幕可视区域而不是 PDF page 坐标决定动作按钮位置：

1. 计算选区顶部到 viewport 顶部空间
2. 计算选区底部到 viewport 底部空间
3. 能完整容纳工具条的一侧优先
4. 两侧都可用时选择空间更大的一侧
5. 上下空间都低于 `screenHeight * 20%` 时，将工具条放到选区垂直中心
6. X 始终按 viewport 水平中心对齐
7. 移动端避让右上角 AI 模式控件

## 7. AI 流式 UI

### FollowTailScrollController

流式气泡高度增长时，在 `correctForNewDimensions` 中使用 `correctPixels()` 并返回 `false`，让 viewport 在同一 frame 重新 layout，避免“offset 已正确但画面下一帧才跳”的闪烁。

### StreamingAiSidebarController

当用户上滚阅读历史且模型仍在流式输出时，临时延后高频昂贵 rebuild；用户回到底部或进入完成/错误终态时再 flush。

### Markdown 成本控制

- stream preview 约 40 ms 合并
- 未闭合代码围栏先使用纯文本
- reasoning 折叠态避免完整 Markdown 解析

## 8. WiFi 传书

`WifiTransferService` 在移动传书页面生命周期内启动 `HttpServer`：

- 默认端口 8080，被占用时回退随机端口
- 只接受 `.pdf`
- 最大 512 MB
- 校验 `%PDF-` header
- 上传先写临时文件，再 rename commit
- 页面销毁时停止 server

当前安全假设是“受信任同一局域网”。后续若公开分发，建议增加随机 session token / upload token。

## 9. 平台层

### macOS

- Finder / Dock / 默认打开方式文件路径接入
- Vision OCR
- DMG 打包

### Windows

- Windows.Media.Ocr
- `.pdf` 文件关联
- Inno Setup EXE installer

### Linux

- DEB / RPM
- desktop entry / icons

### Android

- 标准 Flutter Android Runner
- Mobile CI debug APK
- `v*` tag 时 release-mode APK
- 当前 release 使用 debug signing，生产分发前需正式 keystore

### iOS

- 标准 Flutter iOS Runner
- 本地网络用途说明用于 WiFi 传书
- CI 验证 simulator build
- 尚未配置生产签名/IPA 发布链路

## 10. CI / Release

### Mobile CI

执行：

```text
flutter pub get
flutter test
flutter analyze --no-fatal-infos
flutter build apk --debug
flutter build ios --simulator
```

### Build Packages

普通 `main` push：

- Linux DEB + RPM
- Windows EXE
- macOS DMG

明确推送 `v*` tag：

- 上述三平台
- Android release-mode APK
- 四个平台成功后统一 Publish GitHub Release

## 11. 测试现状

当前已覆盖的重点包括：

- AI response/session
- stale stream / clear during stream
- AI Sidebar state sync
- 流式 scroll 与同帧渲染断言
- streaming rebuild suppression
- API Key bottom sheet
- PDF AI context / selection model
- 跨页 selection model
- selection toolbar 屏幕定位
- reader state / toolbar layout
- WiFi transfer service

因此测试已经不再是早期“启动空态 + outline mapper”的轻覆盖状态。

## 12. Agent 阅读顺序

建议按下面顺序进入仓库：

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
AiSidebarController / StreamingAiSidebarController
  ↓
AiAgentSession + PdfAiContextService
  ↓
DeepSeekService
```

若问题是桌面平台行为，再进入 `windows/` / `macos/` / `linux/`；若问题是移动 Runner/权限，再进入 `android/` / `ios/`。
