# Changelog

## 0.1.2 - 2026-09-03

### AI 流式停止

- AI 流式输出期间，原“发送”按钮不再 disabled，而是切换为可点击的“停止生成”状态；点击后 UI 立即结束 loading 并恢复普通发送按钮。
- 停止不是只忽略后续 token：`HomeController.stopAiResponse()` 会调用 `AiAgentSession.stopActiveStream()`，直接取消当前 `StreamSubscription`，让 DeepSeek SSE 停止继续消费并进入 transport 资源释放路径。
- 用户停止前已经收到的正文与 reasoning 会保留，并作为本轮部分回复收尾；停止后不再追加后续增量。
- 第一个 token 尚未返回时停止，会移除空的 AI loading 占位；对话 history 不留下悬空的 user 请求。
- 如果点击停止时请求仍处于 PDF / document context 准备阶段，则复用现有 `_aiActionId` 失效保护，阻止本轮继续进入模型 stream。
- 新建 AI 会话与 `HomeController.onClose()` 都会主动取消当前 stream，避免旧请求在新会话或页面销毁后继续占用网络资源。
- 取消过程中 transport 恰好抛错时，以用户主动停止语义为准，不再让取消收尾异常反向覆盖已经停止的 UI 状态。

### UI 与状态收尾

- `ChatInputBar` 在生成期间继续禁用文本输入与“新建会话”，但发送按钮位置始终可操作，并切换为 stop 图标和“停止生成”提示。
- `AiSidebarController` 在 loading 结束时统一结束最后一条 AI 消息的 loading 状态；若该消息既没有正文也没有 reasoning，则直接移除空占位。
- 主动停止会清空本轮尚未完成的 follow-up suggestions，避免把未完成响应的建议暴露为可继续追问的终态结果。
- 既有流式滚动策略保持不变：用户在底部时继续同帧 follow-tail；主动上滚阅读历史时不被新 token 强制拉回；stop 属于终态刷新，不会被 deferred streaming rebuild 吞掉。

### 测试与验证

- 新增 ChatInputBar 回归测试：`loading=true` 时发送按钮切换为可点击“停止生成”。
- 新增 `AiAgentSession` 回归测试：主动停止会真实触发底层 stream subscription cancel，并保留已经收到的部分 assistant 回复。
- 新增 AI Sidebar 停止状态测试：首 token 前停止会移除空 loading；已有部分正文时停止只结束 loading、不删除内容。
- PR #8 最终 Mobile CI Run #108 已通过完整 `flutter test`、`flutter analyze --no-fatal-infos`、Android arm64 debug build 与 APK ABI 校验。

### 发布

本版本发布元数据：

```text
version:      0.1.2+26
msix_version: 0.1.2.0
commit:       release: v0.1.2
tag:          v0.1.2
```

GitHub Release 预期包含：

- Linux `.deb`
- Linux `.rpm`
- Windows `.exe`
- macOS `.dmg`
- Android `plume-pdf-android-arm64-v8a-v0.1.2.apk`

当前仍不生成 iOS 二进制发布资产。

## 0.1.1 - 2026-09-03

> `v0.1.1` 是 Plume PDF 从早期 `0.0.x` 快速迭代进入第一个稳定里程碑的版本。本次发布不只是版本号提升：移动端阅读骨架、跨页 AI 框选、流式 AI 对话、桌面/Android 自动发布已经形成完整链路，同时对 Reader 状态源、AI Sidebar 生命周期和 DeepSeek transport 做了系统性收敛，删除了一批重复机制和历史兼容路径。

### 修复

- 修复 PDF 获得焦点后按 Escape 无法退出 AI 框选的问题，并补充“焦点位于 Reader 后代节点时 Escape 仍可退出”的回归测试。
- 修复 widget 更新期间触发 selection 回调导致的隐患，为 selection overlay 的 widget 更新生命周期增加保护与测试。

### 样式

- 细化 AI 框选模式徽标：调整水平位置、强化黑色渐变、加速金色流程动效。

### 本次版本定位

Plume PDF 目前是一套以 Flutter + PDFium (`pdfrx`) 为基础的跨平台 PDF + AI 阅读器：

- Windows / macOS / Linux 继续使用桌面阅读 Shell
- Android 使用独立移动阅读 Shell，并发布 `arm64-v8a` APK
- iOS 工程继续保留在仓库中，但当前阶段不进入 CI，也不发布 iOS 二进制
- 桌面端和移动端共享同一套 `HomeController`、`PdfReaderState`、`PdfViewerController` 与 AI 会话层
- 当前生产 AI Provider 仍为 DeepSeek，但 `AiModelRegistry` / `AiModelConfig` 保留，为后续多模型扩展预留配置层

### Android / 移动阅读基础

- 标准 Flutter Android/iOS 工程已经进入主仓库；移动端启动路径与桌面的 `window_manager` 初始化隔离。
- Android/iOS 使用 `MobileHomeView`，桌面 Windows/macOS/Linux 继续使用 `HomeView`，没有复制第二套 Reader Controller。
- 移动 PDF 区域真实让出顶部 SafeArea、底部工具栏和系统底部安全区，避免内容被刘海、手势条或固定工具栏覆盖。
- 目录、AI、WiFi 传书使用全屏移动路由，同时复用桌面端已有的 Reader / AI 业务状态。
- 移动 AI 输入区在系统底部 inset 基础上额外保留 20 px，兼容底部安全区为 0 的设备。
- Android 当前只构建 ARMv8-A / `arm64-v8a`，CI 会检查 APK 内原生库 ABI，防止意外混入其他架构。
- WiFi 传书在页面打开期间启动临时本地 HTTP 服务：只允许 PDF、限制最大 512 MB、检查 `%PDF-` 文件头，上传完成后自动打开；离开页面后服务关闭。

### Viewer 级跨页 AI 框选

- AI 框选从“每页一个 overlay”升级为整个 `PdfViewer` 唯一一份 `PdfViewerAreaSelectionOverlay`。
- 全局任何时刻最多只有一个框选区域和一组 `翻译 / 解释 / 深度理解` 操作，不再出现不同页残留多组选区。
- 一个选区可连续跨越多页，并转换为多个 `PdfAiSelectionRegion`；文字按页顺序合并，截图/OCR 回退按命中页裁剪后聚合为一次 AI 上下文。
- PDF 连续阅读的纵向 page gap 收敛为 0，使跨页框选和视觉连续性更自然。
- AI 动作工具条按真实 viewport 屏幕空间决定放在选区上方或下方；上下都不足屏幕高度 20% 时回退到选区垂直中心，并保持屏幕水平居中。

### AI 流式体验与滚动稳定性

- `AiAgentSession` 将原始 SSE preview 合并到约 40 ms 节奏，避免每个 token 都触发昂贵 GetBuilder / Markdown rebuild。
- `FollowTailScrollController` 在 `correctForNewDimensions` 中进行同帧 viewport correction：不仅滚动数值贴底，最新气泡也在当前 frame 内完成重新 layout，修复“数值正确但画面下一帧才跳”的闪烁。
- 用户主动上滚阅读历史时不再被流式输出强制拉回底部；回到底部阈值后恢复自动跟随。
- 原独立 `StreamingAiSidebarController` 已删除，其“用户离开底部时延后 streaming rebuild、回到底部或终态时 flush”的职责并入 `AiSidebarController`。
- 未闭合的流式代码围栏优先使用轻量文本展示，reasoning 折叠态避免无意义的完整 Markdown 重解析；展开后再使用完整 Markdown。
- 保留 render-level 回归断言，确保未来 Flutter ScrollPosition 行为变化时能检测“offset 对但画面晚一帧”的问题。

### Reader 状态源与异步竞态收敛

- 页码不再由 `PdfViewerController` listener 与 `onPageChanged` 两条路径重复写入。
- 当前语义明确拆分为：
  - `PdfViewerParams.onPageChanged`：唯一页码事件源，负责 `currentPage`、目录选中项、页码输入框和阅读进度
  - `PdfViewerController` listener：只同步 zoom
- 这样避免 pdfrx transformation listener 与 layout 后页码计算之间的时序差异。
- Viewer page callback / document callback 都携带来源 `filePath`；切换 PDF 后，旧 Viewer 的延迟回调不会污染当前文档。
- Outline 加入 `loadId + filePath` 双重失效保护，旧 PDF 的慢异步结果无法覆盖新 PDF 目录。
- 阅读进度 debounce 捕获触发当时的 file/page 快照，并在执行时确认仍是同一文件，避免快速切文档或回到最近阅读页时保存错误路径/页码。
- 原本多套快捷键输入路径收敛为 `CallbackShortcuts + Focus`，保留 Escape、打开文件、翻页、缩放、复位等行为，删除重叠的 HardwareKeyboard/Focus 处理。

### AI Sidebar 生命周期统一

- `AiSidebarController` 只由 `HomeController` 创建、注册和销毁。
- `MobileAiView` 删除第二套 `_ensureAiController()` / `Get.put()` 创建路径，恢复为纯展示 View。
- HomeController 只在 `aiPanelState`、当前文档路径或左侧栏可见性真正影响 AI Sidebar 时同步外部状态，page/zoom/recent 等无关 Reader 更新不会再让 AI Markdown 区重复 rebuild。
- Debug Gallery 使用独立 Controller tag，避免预览页复用并删除 Home 正在使用的 AI Controller。

### DeepSeek transport：移除 Genkit 双通道

- 删除 `genkit` 与 `genkit_openai` runtime 依赖，以及 Genkit 实例缓存、`Message/Part/Media` 中间转换和历史兼容 API。
- `DeepSeekService` 当前只有一条 OpenAI-compatible HTTP/SSE transport：

  ```text
  AiAgentSession
      ↓
  DeepSeekService.performStream / chatStream
      ↓
  POST https://api.deepseek.com/v1/chat/completions
      ↓
  SSE
      ├─ reasoning_content
      └─ content
  ```

- 文本、历史、多模态图片直接生成 OpenAI-compatible message JSON，不再先构造 Genkit 对象再转换一次。
- 保留 `deepseek-v4-flash-vision-exp`、多轮历史、历史图片/MIME 类型、日常动作 `reasoning_effort=low` 和“深度理解”32768 completion token budget。
- SSE 继续保留 HTTP 状态检查、JSON 类型检查、无效 chunk 跳过和客户端生命周期清理。

### Vision fallback 正确性

- 过去视觉请求只要抛出 `DeepSeekException` 就可能再次发送纯文本请求，认证失败或网络错误也可能导致一次用户操作发出第二次请求。
- 本次发布只允许在 HTTP 400/422 且服务端错误明确包含 image / vision / media / multimodal 能力拒绝时回退文本。
- 401 API Key 错误、限流、普通网络错误直接展示原错误，不重复消耗请求/token。
- 修复 `invalid image input` / `invalid_request_error` 被通用 `invalid` 关键字误归类成“API Key 认证失败”的问题：400/422 保留真实服务端详情，因此仍能正确判断是否允许 vision → text fallback。

### AI 隐私与请求代数继续保持

- AI 文档上下文不发送本机文件目录和文件大小，避免泄露用户名、公司目录或本地路径结构。
- PDF 正文以不可信数据边界传给模型，并清理可能伪造边界标签的文档内容。
- `HomeControllerAiSession` 的 action id 与 `AiAgentSession` generation 继续阻止旧 stream 在新会话/新请求后覆盖 UI 或 history。
- stale stream 会停止消费后续增量；preview timer 在完成、失败、取消时清理。

### CI 调整

- `Mobile CI` 从 `macos-latest` 切换到 `ubuntu-latest`。
- 当前 Mobile CI 只执行：

  ```text
  flutter pub get
  flutter test
  flutter analyze --no-fatal-infos
  flutter build apk --debug --target-platform android-arm64
  verify APK native ABIs == arm64-v8a
  ```

- 暂时移除 iOS simulator build。当前没有发布 iOS App 的计划，不再让 iOS 编译占用每个 PR/main push 的 CI 时间。
- iOS 工程本身没有删除；未来恢复 iOS 发布时再恢复 simulator/release/signing 验证。

### 自动打包与 GitHub Release

- 普通 `main` push 继续构建：
  - Linux DEB + RPM
  - Windows Inno Setup EXE
  - macOS DMG
- 正式发布使用 `pubspec.yaml` 版本与 release commit 驱动：

  ```text
  version: 0.1.1+25
  commit message: release: v0.1.1
  ```

- `Build Packages` 会自动解析版本并创建/校验 `v0.1.1` tag。
- Release 模式额外构建 Android `arm64-v8a` release APK。
- Linux / Windows / macOS / Android 全部成功后，工作流从本章节提取 Release Notes，创建 GitHub Release，并上传全部安装包。

### 0.1.1 发布产物

预期 Release 页面包含：

- Linux `.deb`
- Linux `.rpm`
- Windows `.exe`
- macOS `.dmg`
- Android `plume-pdf-android-arm64-v8a-v0.1.1.apk`

iOS 当前不生成二进制发布资产。

### 代码健康度

以 `release: v0.0.22` 的 `14685f5` 为重构前基线，到第四轮重构完成的 `42b17e9`（不含本次 v0.1.1 文档扩充）：

```text
生产 Dart 代码 lib/**   -392 行
测试 test/**            +55 行
依赖 pubspec*           -138 行
CI                       -3 行
全仓库净变化            -478 行
```

这次减少的重点不是“为了数字删代码”，而是删除重复状态源、重复 Controller、历史 transport 和不再使用的依赖；测试代码反而净增加，覆盖了 page source、跨文件 debounce、旧 outline 竞态、AI streaming、vision fallback 等行为。

### 验证

重构合并前后已多轮通过：

- Flutter 全量测试
- `flutter analyze --no-fatal-infos`
- Android arm64 debug APK
- APK ABI 校验只包含 `arm64-v8a`
- Linux Release + DEB + RPM 打包链路
- Windows Release + Inno Setup installer 链路
- macOS Release + DMG 链路

v0.1.1 release commit 已触发完整 `Build Packages`，最终以 GitHub Release 页面实际上传的安装包作为发布完成标准。

### 已知限制 / 发布说明

- Android release build 当前仍使用 debug signing，只适合自测和自托管分发；正式 Play Store / 生产分发前必须配置 production keystore。
- WiFi 传书当前假设处于受信任局域网，尚未增加随机 session/upload token。
- iOS 当前暂停 CI 和正式分发，仓库保留 iOS 工程但本版本不提供 IPA。
- 当前生产 AI Provider 仍为 DeepSeek；多模型 registry 被保留，但 Provider 抽象将在真正接入第二个模型时再完成，避免当前阶段过度设计。

## 0.0.20 - 2026-09-01

### Android / iOS

- 新增标准 Flutter `android/`、`ios/` 工程，并将移动端启动逻辑与桌面 `window_manager` 初始化隔离；Android/iOS 使用 `MobileHomeView`，Windows/macOS/Linux 继续使用原 `HomeView`。
- 新增移动端固定阅读工具栏，目录、AI、WiFi 传书使用独立全屏路由，同时继续复用 `HomeController`、`PdfReaderState`、`PdfViewerController`。
- 移动阅读器按系统 SafeArea 为 PDF 真正让出顶部/底部区域；AI 输入区在底部安全区基础上额外保留 20 px，兼容 bottom inset 为 0 的设备。
- 新增 WiFi 传书：受信任同一局域网内通过临时 HTTP 页面上传 PDF；限制 PDF 扩展名、512 MB 大小并校验 `%PDF-` 文件头，离开页面后停止服务。

### AI 框选

- 框选 Overlay 从“每页一份”提升为整个 `PdfViewer` 唯一一份，全局任何时刻最多一个选区和一组 `翻译 / 解释 / 深度理解` 按钮，修复跨页后出现多组选区的问题。
- PDF 页面纵向 gap 改为 0；框选不再受当前页限制，可连续跨多页。一个 `PdfAiSelection` 可包含多个 `PdfAiSelectionRegion`。
- 跨页文本按页顺序合并；截图/OCR 回退按页裁剪后纵向拼接，仍作为一次 AI selection 处理。
- 动作工具条改为真实屏幕坐标定位：比较选区顶部/底部可用空间，始终屏幕 X 轴居中；上下空间都低于屏幕高度 20% 时回退到选区垂直中心，并避让移动端 AI 模式控件。

### AI 对话性能与移动体验

- AI 流式 preview 合并到约 40 ms 节奏，减少每个 token 导致的重复 GetBuilder/Markdown rebuild。
- 新增 `StreamingAiSidebarController`：用户上滚阅读历史时延后流式昂贵 rebuild，回到底部或进入终态后一次性刷新。
- `FollowTailScrollController` 使用同帧 viewport correction 避免流式贴底时一帧晚跳造成闪烁；保留渲染层回归测试。
- 未闭合的流式代码围栏暂用纯文本渲染；折叠 reasoning 使用轻量文本，展开后再使用 Markdown。
- 移动端 API Key bottom sheet：空值不保存也不关闭；有效值持久化成功后自动关闭。
- AI 模型输出区域改为左右对称内容布局，弱化“人与人聊天气泡”视觉。

### CI / 发布

- 新增 `Mobile CI`：执行 `flutter test`、`flutter analyze --no-fatal-infos`、Android debug APK、iOS simulator build，并在合入后继续保护 `main`。
- 桌面发布链路重新验证：Linux release + DEB + RPM、Windows release + EXE installer、macOS release + DMG 全部通过并能上传 Artifact。
- `Build Packages` 仅在明确 `v*` tag 时额外构建 Android release 模式 APK；普通 `main` push 不生成 Android release APK。
- Tag 发布等待 Linux、Windows、macOS、Android 四个平台产物后统一创建/更新 GitHub Release；Android 文件名为 `plume-pdf-android-<tag>.apk`。
- 当前 Android release 仍使用 debug signing；正式生产分发前需配置 keystore。

### 验证

- 新增/扩展 AI preview 合并、定时器清理、流式滚动、移动 API Key、跨页 selection、屏幕工具条定位、WiFi 传书等回归测试。
- 移动端全量测试、静态分析、Android debug build、iOS simulator build 通过；桌面 Linux/Windows/macOS release 打包链路通过。

## 0.0.19 - 2026-08-30

### 隐私与安全

- 不再向 DeepSeek 发送本机文件目录与文件大小：AI 文档上下文移除 `directory`/`fileSize` 字段，模型只接收标题、页码、目录结构与页面正文，避免泄露用户名、公司与本地目录结构。
- PDF 提取内容以不可信数据边界包裹：system prompt 明确声明文档数据中的任何指令都只是文档文字、不得执行，并用 `<document_context>` 标签分隔；页面正文与目录标题中伪造的开/闭标签会被清理，防止恶意 PDF 提前闭合边界注入指令。

### 修复

- 修复 AI 请求竞态：新建会话使进行中的旧流立即失效，预览、终态、错误展示与视觉回退全部校验请求代数，旧请求不再覆盖新会话 UI；会话层代数同时阻止旧请求把结果写入已清空的新会话历史，并停止消费后续增量以节省 token。
- 对话（`sendAiChat`）路径此前没有请求代数，现已与框选动作共用同一序列，任何新动作都会使旧流失效。

### 验证

- 新增会话清空竞态（动作/对话两条路径）、文档上下文隐私字段移除、不可信边界包裹与伪造标签清理回归测试；全量测试与 Dart 静态分析通过。

### 维护

- 同步 `msix_version` 至 `0.0.19.0`（此前落后于应用版本）；新增 `docs/todo.md` 记录后续架构计划。

## 0.0.18 - 2026-08-30

### 修复

- 修复流式输出贴底跟随时的底部闪烁：`FollowTailScrollController` 的同帧贴底修正此前未触发 viewport 重排（`applyContentDimensions` 返回值语义用反），导致滚动位置数值正确但画面晚一帧跳动；改用 `correctForNewDimensions` 契约（修正后返回 false 触发同帧重排），渲染前已经贴底。
- 滚动回归测试新增渲染层断言（最新气泡必须画在视口内），可捕获"数值正确但画面晚一帧"类缺陷。

### 字体

- 聊天框 markdown 文本回调为 `OPPO Sans`；行内代码与代码块保持 `Google Sans Mono`。
- 移除不再使用的 `MapleMono` 字体资产（约 20.5MB）。

## 0.0.17 - 2026-08-30

### AI 架构分层

- 拆分 `HomeControllerAiSession`：新增 `AiAgentSession` 会话层（对话历史、流式累积、响应解析与历史写入）与 `PdfAiContextService` 提取层（选区文本/截图、页面上下文、文档级 AI 上下文），控制器收敛为薄编排层。
- 消除翻译/解释/深度理解/多轮对话多处重复的流式累积与终态写入逻辑。

### AI 侧边栏滚动

- 消息列表改为 reverse 布局锚定底部，消除流式输出贴底跟随时的上下跳动/闪烁。
- 流式气泡增高时对滚动 offset 做增量补偿，用户上滚阅读历史不再被持续推走。
- 用户滚回底部阈值内时恢复自动跟随并贴底，后续流式输出重新可见。

### Markdown 渲染

- 思考过程（reasoning）按 markdown 渲染，默认折叠八行并渐隐，可点击展开；标题样式收敛以适配紧凑面板。
- 关闭 h1 标题后自动附加的分割线；模型输出的 `---` 水平线在组件层隐藏，代码块内的 `---` 不受影响。

### 模型调用

- DeepSeek V4 思考模式按动作分档：翻译/解释/多轮对话使用 `reasoning_effort=low` 缩短思考过程，深度理解保留默认档位。

### 字体

- 新增 `MapleMono`（Maple Mono NF CN，Markdown 文本统一字体）与 `GoogleSansMono`（行内代码与代码块）字体资产。
- 移除 gpt_markdown 本地包内置的 `JetBrainsMono` 字体文件与注册。

### 验证

- 新增会话层流式、贴底滚动稳定性、恢复跟随、滚动补偿、分割线隐藏、推理深度分档等回归测试；全量测试与 Dart 静态分析通过。

## 0.0.16 - 2026-08-23

### AI 侧边栏与输入

- 新增 PDF 上下文和 AI 对话历史模型，支持在侧边栏对当前文档进行连续问答。
- 支持流式展示 AI 思考过程和正式回答，并修复长回答显示不完整的问题。
- 剪贴板图片、本地图片路径和 `file://` 图片路径统一转换为图片附件后发送给模型。
- 修复输入框提示文字未从左上角开始布局的问题。

### 验证

- 新增 PDF 上下文、图片路径附件和输入框布局回归测试。
- 通过 Dart 静态分析和相关 Flutter 定向测试。

## 0.0.15.1 - 2026-08-23

- AI 侧边栏控制器改由 `HomeController` 统一创建并注册（`GetBuilder` 不再使用 `init`），收起侧栏后会话历史保留。

## 0.0.15 - 2026-08-23

### AI 侧边栏与对话体验

- 新增专用 `AiSidebarController`，使用 GetX 统一管理 AI 侧边栏模式、会话消息、输入框、滚动状态和资源生命周期。
- 整理 AI Sidebar 视图结构，移除原有硬编码追问文案与混杂在 Widget 中的业务状态。
- AI 根据当前问题、回答内容、页面上下文和历史对话生成追问建议，Sidebar 只展示模型返回的动态建议。
- 新增 AI 响应解析器，分离流式回答正文与结构化追问建议，避免协议标记出现在聊天气泡中。
- 多轮对话请求补充上下文系统提示，模型回复完成后将清洗后的正文写入对话历史。

### 验证与维护

- 新增 AI 响应解析、动态追问建议和 DeepSeek 多轮系统提示测试。
- 通过 Flutter 全量测试、Dart 静态分析和 Windows Release 构建验证。

## 0.0.14 - 2026-08-23

### AI 对话与模型能力

- 接入 Google Genkit 重构 DeepSeek 调用链路，替换原 HTTP 直连，实现流式对话输出。
- 统一切换为 DeepSeek vision 模型，引入 genkit 依赖。
- 新增"深度理解"动作：教学式长文讲解，覆盖原"解释"动作的简短回答。
- 翻译动作明确输出方向：中文→英文 / 英文→中文，仅输出译文，并在译文后紧跟 1-2 句内容总结。
- 用户气泡新增选区截图与选中文本展示，区分纯文本对话与划词操作。
- 模型回复完成后展示追问建议 chips（Wrap 组件）。
- 输入栏新增"新建会话"按钮，任务进行中禁用。

### AI 视觉与样式

- loading 占位改为 ballPulse 三点动画（单色半透明白，无文字）。
- 对话文本行高从 1.5 提升至 2.0（用户侧与模型侧统一）。
- 修复用户气泡仅显示动作标签、丢失选区文本的问题。
- 修复动作时序：用户气泡先于模型 loading 出现。
- 模型直接输出不再提及"图片"字样；用户气泡带截图时仅展示图片。
- 行内代码去掉上下内边距，垂直更紧凑。

### 全局字体

- 全局字体切换为 `OPPO Sans`，并把 Windows 常用字体作为 fallback，避免系统差异导致中文回退异常。
- `gpt_markdown` 本地包保留 JetBrains Mono 作为代码块字体。

### 设置与模型配置

- DeepSeek 设置项新增“模型”选择，默认显示 `deepseek-v3.2-speciale`。
- 模型列表与能力通过 `assets/config/ai_models.json` 读取，至少包含 `deepseek-v3.2-speciale` 与 `deepseek-v4`。

### 验证

- 通过 `dart analyze lib/` 和全量 Flutter 测试。

## 0.0.13 - 2026-08-22

- AI 设置页由右侧边栏改为模态弹窗，固定在应用窗口中间显示。
- 移除 AI 侧边栏底部 API Key 未配置提示横条。
- 统一调整 AI 对话字体与行高：用户气泡、模型回复、思考过程、追问 chips、输入框分别使用 15/15/14/14/15 px，正文行高统一提升到 1.5。
- 优化 AI 输入框发送按钮样式：移除圆形边框，保持更轻的 hover / disabled 状态。

## 0.0.12 - 2026-08-22

- AI 侧边栏组件化：抽出 ChatBubble、ReasoningPanel、FollowUpChips、ChatInputBar、设置 UI 等子组件。
- AI 输出支持 Markdown 渲染，代码块使用 `gpt_markdown` 与 `highlight` / `flutter_highlight` 高亮。
- DeepSeek API Key 改为 SharedPreferences 持久化，不再提交真实 API Key；设置为空时会删除本地 Key。
- 发送按钮改为向上箭头样式，并优化 loading 与错误态显示。

## 0.0.11 - 2026-08-22

- 双页模式下左右页缩放比例保持一致，并支持根据两页组合宽高居中显示。
- 修复双页模式开启后页面之间间距和 fit-width 计算不一致的问题。

## 0.0.10 - 2026-08-22

- 顶部工具栏加入单页 / 双页切换按钮，双页模式按 1-2、3-4 的顺序并排展示。
- 修复切换双页后缩放状态没有同步的问题。

## 0.0.9 - 2026-08-22

- PDF 渲染从 `pdfx` 迁移到 `pdfrx`，获得 PDFium 渲染、outline、页面控制与更稳定的桌面支持。
- 支持目录点击跳转、最近文件记录、阅读进度恢复。

## 0.0.8 - 2026-08-22

- 新增 macOS 原生 Vision OCR，并接入图片型 PDF 的 AI 兜底识别。
- 新增 Windows 原生 `Windows.Media.Ocr`，统一图片型 PDF 的 OCR 回退链路。

## 0.0.7 - 2026-08-21

- 增加 Windows `.pdf` 文件关联与默认打开方式支持。
- 增加 macOS Finder / Dock 传入 PDF 的原生 openFiles 回调。

## 0.0.6 - 2026-08-21

- 增加 Linux `.rpm` / `.deb` 打包脚本与桌面入口。

## 0.0.5 - 2026-08-20

- 增加 Windows MSIX / Inno Setup 打包流程。

## 0.0.4 - 2026-08-19

- 增加 macOS DMG 打包流程。

## 0.0.3 - 2026-08-18

- 增加桌面拖拽打开 PDF、最近文件网格与阅读进度持久化。

## 0.0.2 - 2026-08-17

- 增加 PDF outline、翻页、跳页、缩放、单/双页阅读等基础阅读能力。

## 0.0.1 - 2026-08-16

- 初始化 Flutter 桌面 PDF 阅读器。
