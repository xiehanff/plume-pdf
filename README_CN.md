# Plume PDF

[English](./README.md) | 中文

Plume PDF 是一个基于 Flutter + PDFium（`pdfrx`）的跨平台 PDF 阅读器，并集成 DeepSeek AI 辅助阅读。桌面端和移动端共用阅读状态/控制层，只在 UI Shell 与导航表现上按平台拆分。

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
- AI 区域框选动作：`翻译`、`解释`、`深度理解`
- 框选属于整个 PDF Viewer，而不是某一页，因此一个框选可以连续跨越多页
- 全局任何时刻只存在一个框选框和一组动作按钮，不会在不同页残留两组选区
- 三个动作按钮根据框选区域在真实屏幕中的上下可用空间定位，而不是按当前页位置判断；当上下空间都不足屏幕高度 20% 时，按钮回退到框选区域垂直中心，并始终保持屏幕 X 轴居中
- 跨页文字按页顺序提取并合并；截图/OCR 回退会裁剪每个命中的页面区域并合成为一次 AI 上下文
- 支持视觉理解的模型优先使用截图；必要时回退本地 OCR / PDF 文本提取
- AI 流式输出在用户上滚阅读历史时抑制高频昂贵 rebuild，回到底部后恢复跟随；同帧滚动修正确保贴底输出不闪烁
- Markdown 使用本地 fork 的 `gpt_markdown`，代码块支持语法高亮

### 桌面端

- macOS：Finder / Dock / 窗口拖拽打开 PDF，原生 Vision OCR
- Windows：`.pdf` 文件关联、原生 OCR、快捷键、Inno Setup 安装包
- Linux：提供 `.deb` 与 `.rpm` release 包

### 移动端

- 已加入标准 Flutter Android / iOS 工程
- 使用独立 `MobileHomeView`，桌面 `HomeView` 保持原结构
- 阅读区完整处理顶部/底部安全区，并提供固定移动端工具栏
- 目录、AI 使用全屏移动路由，但继续复用同一套 `HomeController`、`PdfReaderState`、`PdfViewerController`
- 移动 AI 输入区域在系统底部安全区基础上额外保留 20 px
- WiFi 传书：打开传书页面期间，在受信任的同一局域网中临时启动 HTTP 服务，电脑浏览器可上传 PDF，上传成功后手机自动打开文档；离开页面后服务停止

## 平台状态

| 平台 | 状态 | 说明 |
|---|---|---|
| macOS | 可用 | 原生 Vision OCR、PDF 打开集成、DMG 发布打包 |
| Windows | 可用 | 原生 OCR、`.pdf` 关联、EXE 安装包 |
| Linux | 可用 | DEB + RPM 发布打包 |
| Android | 可用 | CI 验证 debug APK；明确打 `v*` tag 时额外生成 release 模式 APK |
| iOS | 可用 | 已验证 simulator build；尚未配置生产签名与正式分发 |

> Android 当前 `release` buildType 仍使用仓库中的 debug signing 配置。该 APK 适合自测/自托管分发；正式上架 Play Store 或生产分发前必须接入正式 keystore。

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

# 移动端
fvm flutter run -d android
fvm flutter run -d ios
fvm flutter build apk --debug
fvm flutter build ios --simulator
```

## CI 与发布

仓库现在有两条主要 Actions：

- `Mobile CI`：在 `main`、移动端开发分支及相关 PR 上执行测试、静态分析、Android debug APK、iOS simulator build。
- `Build Packages`：普通 `main` push 构建并上传 Linux DEB+RPM、Windows EXE、macOS DMG。

只有明确推送 `v*` 版本 tag 时，才额外生成 Android release APK 并发布 GitHub Release：

```bash
git tag v0.0.20
git push origin v0.0.20
```

Tag 发布会等待 Linux、Windows、macOS、Android 四个平台打包成功，然后将产物统一放入同一个 GitHub Release。Android 文件名类似：

```text
plume-pdf-android-v0.0.20.apk
```

普通 `main` push **不会**生成 Android release APK。

## 分发文档

- [Windows 安装包生成与分发](./docs/windows-installer-distribution.md)
- [Linux Debian 包分发说明](./docs/linux-deb-distribution.md)
- [Linux RPM 包分发说明](./docs/linux-rpm-distribution.md)

## 架构说明

- PDF 渲染：`pdfrx` / PDFium
- 路由与状态：GetX
- 共用阅读编排：`HomeController` + `PdfReaderState` + `PdfViewerController`
- 桌面 Shell：`HomeView`
- 移动 Shell：`MobileHomeView`，目录 / AI / WiFi 传书使用独立全屏路由
- AI 编排：`HomeControllerAiSession`
- AI 会话、历史与流式累积：`AiAgentSession`
- PDF 文本 / 截图 / OCR 上下文：`PdfAiContextService`
- AI 调用：`DeepSeekService`（Genkit）
- 流式 UI 优化：`StreamingAiSidebarController` + `FollowTailScrollController`
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
- `http`：HTTP 工具
- `genkit` + `genkit_openai`：DeepSeek 流式调用
- `shared_preferences`：最近文件 / 阅读设置持久化
- `path_provider`：应用目录，包括移动端 WiFi 传书文件存储
