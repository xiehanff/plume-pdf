# Changelog

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
