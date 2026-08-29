# Changelog

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

- 全局字体切换为 OPPO Sans，代码渲染保留 JetBrainsMono。

### 选区工具栏 UI

- 选区工具栏改为毛玻璃风格：白半透明模糊容器 + 等宽按钮居中。
- 点击工具栏按钮后自动清除划词区域。
- 划词区域改为深蓝边框 + 浅蓝近透明填充（替换浅紫色）。
- 毛玻璃背景统一为鲜艳饱和蓝 #1D4ED8 @90%，文字改白色。

### 杂项

- 回退运行 app 产生的构建生成文件与锁文件改动。

## 0.0.13 - 2026-08-16

- 修复 macOS 自定义标题栏工具栏区域无法双击最大化/还原的问题。
- 统一 macOS、Linux、Windows 标题栏的拖动与双击窗口状态切换行为。

## 0.0.12 - 2026-08-16

- 修复 Linux/Windows 自定义标题栏中最小化、最大化按钮单击响应延迟。
- 恢复空白标题栏双击最大化/还原，同时避免工具栏按钮被双击手势拖慢。
- 统一窗口最大化按钮与标题栏双击的窗口状态切换逻辑。
- 新增可重复执行的 Linux Debian `.deb` release 打包脚本，并同步更新 RPM/DEB 分发说明。

## 0.0.11 - 2026-08-03

- 修复 macOS 通过 Finder“打开方式”启动 Plume PDF 后未自动加载指定 PDF 的问题，支持单文件、多文件和 URL 文件打开事件。
- 完善 macOS PDF 文件类型注册，提升 Finder 文件关联兼容性。
- macOS 保留原生红黄绿窗口按钮，Linux/Windows 使用自定义窗口控制并支持拖动标题栏。
- 自定义窗口控制按钮统一垂直居中，关闭按钮 hover 背景改为红色，最小化按钮改用 HugeIcons 图标。
- 操作栏右侧功能菜单上下内边距统一，移除操作栏底部分割线。
- 顶部左侧移除重复的文件标题，仅保留侧边栏和打开文件按钮；文件标题继续由底部状态栏展示。
- Release 版本移除工具栏中的 Debug Gallery 入口。
- 新增 Fedora/Linux RPM release 打包链路与发行说明。

## 0.0.10 - 2026-06-20

- 最近阅读补齐可维护能力：每个卡片底部新增删除按钮与添加时间展示，支持单独移除记录。
- 最近阅读进入页面时会实时检测文件路径可访问性；失效条目会显示“无法访问”状态，并提供“删除记录 / 重新打开”操作。
- 最近阅读卡片视觉重新收口：封面改为 `BoxFit.cover` 覆盖容器，底部信息条、不可访问胶囊和右上角操作按钮对齐，去掉多余白底与页码信息。
- 页码输入框增加可编辑态高亮背景，当前页更容易识别为可输入控件。
- 修复页码输入框聚焦后按上下方向键触发 `editable.dart` 断言的问题。
- 新增 `Ctrl/Cmd +/-` 与小键盘 `+/-` 缩放快捷键，行为与工具栏缩放按钮保持一致。

## 0.0.9 - 2026-06-18

- 修复 Windows Inno Setup 安装包的 `.pdf` 文件关联注册；安装后可在“打开方式”中选择 Mint PDF，并在双击 PDF 时直接进入阅读页，不再反复弹出“选择打开方式”窗口。
- Windows 启动参数读取链路补齐；通过文件关联唤起应用时，会读取传入的 PDF 路径并直接打开对应文档。
- 移除 Windows 下自定义线性插值/惯性滚轮驱动（`PdfWheelScrollDriver`），改用 pdfrx 内置逐行滚动行为。
- `scrollByMouseWheel` 由 0.2 提升到 0.9，大幅增大滚轮滚动距离，缓解 Windows 下滚动费力的问题。
- 新增 Linux release `.deb` 包分发，可直接安装到 Debian / Ubuntu 系发行版。

## 0.0.8 - 2026-06-15

- Windows 新增 Inno Setup 安装包链路，可直接把 `build/windows/x64/runner/Release/` 打成安装包，并自动创建桌面/开始菜单快捷方式。
- 新增 `windows/installer/build_installer.ps1` 与 `windows/installer/mint_pdf.iss`，用于重复生成 Windows 安装包。
- `make.ps1` 新增 `build-installer-windows` 命令，便于和现有 `build-msix-windows` 并行维护。

## 0.0.7 - 2026-06-11

- Windows 新增 `.pdf` 文件关联，安装后可在“打开方式”中选择 Mint PDF，并在双击 PDF 时直接打开文件。
- Windows 启动时新增命令行参数接入，系统从文件关联唤起应用后会自动加载传入的 PDF。
- Windows MSIX 打包链路改为真正生效的 `msix_config`，并补齐 `file_extension` 配置。
- Windows 新增圆角图标资源，任务栏 / 开始菜单统一使用新的 Windows 专用图标链路。
- 新增 `scripts/build_windows_msix.ps1`，统一处理 Windows 圆角图标生成和 MSIX 打包。
- `make.ps1` 新增 `build-msix-windows` 命令，便于重复生成 Windows 安装包。

## 0.0.6 - 2026-06-11

- AI 侧边栏新增 SiliconFlow provider 分组，可单独保存 SiliconFlow API Key，并在设置中切换当前 AI provider。
- 新增 `SiliconFlowService` 与模型能力配置：当前接入 `Qwen/Qwen3-VL-30B-A3B-Instruct` 作为视觉理解模型。
- AI 框选新增模型能力判断：支持视觉理解的模型优先走截图渲染并直接发云端理解，失败后再回退到文本层提取 / 原生 OCR。
- 未标记视觉能力的模型不会走截图渲染链路，避免无意义截图与额外开销。
- 修复模型配置异步初始化竞态，避免应用启动早期打开 AI 设置或立即触发 AI 动作时崩溃。
- 新增 PDF 阅读背景主题切换：工具栏 PopupMenuButton 菜单支持 `默认` / `阴天` / `羊皮纸` / `护眼绿` 四种模式。
- 主题切换通过 `ColorFilter` 矩阵在 PDF 渲染层面改变页面颜色，不影响 app 其他 UI。
- 阴天模式：降低 30% 亮度；羊皮纸模式：暖色降低蓝光滤镜；护眼绿模式：豆沙绿矩阵。
- 菜单项当前选中模式左侧显示 HugeIcons.strokeRoundedTick01 对勾。
- 选择持久化到 SharedPreferences，重启后保持。
- 再次修复横向滑动不稳定的问题
- Esc 现在会全局退出 AI 选择模式，不再依赖侧边栏焦点。
- 从“最近阅读”重新打开 PDF 时，会保留已填写的 DeepSeek API Key，不再误清空。
- macOS 新增 PDF 文档类型注册，可在 Finder 的“打开方式”中选择 Mint PDF，并设置为默认打开应用。
- macOS 新增原生文件打开桥接：从 Finder 双击 PDF、拖到 Dock 图标、或通过“打开方式”唤起时，应用会直接加载对应文件。
- 桌面窗口新增 PDF 拖拽打开：将本地 PDF 拖到已打开的 Mint PDF 窗口内，松手后直接打开文件，并继续写入“最近阅读”记录。
- 首页拖拽悬停时新增“松开以打开 PDF”可视化提示，非 PDF 文件拖入时给出错误提示。

## 0.0.5 - 2026-06-08

- 工具栏右侧新增历史记录入口（HugeIcons.strokeRoundedTransactionHistory）。
- 最近文件从左侧边栏移除，改为未打开 PDF 时以田字格展示书籍封面/标题/简介。

## 0.0.4 - 2026-06-08

- 主题配色：鼠尾草绿 → 暗紫色（seed/#686687, accent/#B39DDB）。
- 替换应用图标：macOS .icns、Windows .ico、多尺寸 PNG 全链路更新。
- AI 选择模式标签：暗紫不透明背景 + 旋转彩色渐变边框动画。
- AI 框选上下文：框选翻译/解释时附带整页文本上下文，模型理解更准确。
- AI 对话历史：框选操作与普通追问共享对话历史，第二次框选保留前文。
- Esc 快捷键：按下 Esc 退出 AI 选择模式。
- 底部状态栏：移除 "AI 选择模式已开启" 文字。
- Markdown 行内代码：highlightBuilder 自定义渲染增加内边距。

## 0.0.3 - 2026-06-08

- AI 侧边栏：移除 flutter_chat_ui / flutter_chat_types 依赖，自实现聊天 UI，修复消息显示顺序 bug（AI 回复始终在用户消息下方）。
- AI 侧边栏：Markdown 渲染从 flutter_markdown 切换为 gpt_markdown，代码块使用 flutter_highlight + atom-one-dark 主题语法高亮。
- AI 侧边栏：新增底部对话输入栏，支持用户追问（多轮对话），DeepSeekService 新增 chat 方法。
- AI 侧边栏：移除竖向分割线、输入区上方横向分割线，视觉更统一。
- 项目迁移至 fvm 管理 Flutter 版本（3.32.5），SDK 约束更新为 ^3.8.0，pubspec.yaml 新增 Makefile 封装常用命令。
- pdfrx 从 1.0.101 升级至 1.3.5，适配 Flutter 3.32。
- gpt_markdown 因 Flutter 3.32 API 变更（Radio/SelectedContentRange）本地 fork 至 packages/gpt_markdown，修复兼容问题。
- 代码块高亮主题改为 atom-one-dark，恢复语言头部背景色条。
- 用户气泡右上直角、AI气泡全圆角；输入框背景色与AI气泡统一为 surfaceBg。
- 修复 AI 侧边栏多轮对话历史同步问题：切换 PDF 后清空旧会话，追问继续使用真实对话上下文，不再把本地错误气泡写回模型历史。
- 修复顶部页码导航与目录侧边栏选中抖动：页码输入框改为有限动态宽度，目录跳转时同页多级条目保持用户手动选中的目标项。

## 0.0.2 - 2026-06-07

- 将散落在各视图文件中的硬编码颜色值提取到 `lib/app/theme/app_colors.dart`，建立统一的颜色 token 体系（Backgrounds / Accent / Text / Borders / Fills / Overlays / Selection / Functional）。
- 合并 `borderDefault`（6%）与 `borderSubtle`（5%）为 `borderSubtle`，消除视觉上无意义的 token 冗余。
- 还原 `deepseek_service.dart` 中与颜色重构无关的冒号改动。

## 0.0.1 - 2026-06-06

- 更新应用图标资源，统一 `assets/` 与 macOS AppIcon 资产。
- 缩小双页模式页间间距（左右、上下从 24px 调整为 8px），减少空间浪费。
- 新增 AI 框选模式：支持区域框选、框选后点击空白处清除、拖动已选区域移动位置。
- 框选后新增黑色半透明 AI 工具条，提供 `翻译` / `解释` 两个入口。
- 新增右侧 AI 侧边栏，支持配置 `DeepSeek API Key` 并展示 AI 返回内容。
- AI 侧边栏背景色与左侧阅读侧边栏统一。
- 新增 macOS Vision OCR 兜底链路：文本型 PDF 优先提取文本层，图片型 PDF 改为区域渲染后 OCR，再接 DeepSeek。
- 中间缩放百分比显示改为按钮样式，点击后恢复到真正的 `100%`。
- 修复双页模式下 `适宽` 行为不正确的问题，改为按当前 spread 整体适配。
- 阅读区整体增加统一内边距，并让内边距与 PDF 渲染背景保持一致。
- 翻页后目录侧边栏选中状态会按当前页自动联动。

- macOS 应用名从 mint_pdf 改为 Mint PDF。
- macOS 窗口启动时最大化。
- 添加 Debug Gallery 页面，debug 模式下可从工具栏虫子图标进入，预览所有提示视图状态。
- 统一 EmptyReaderView 和 ErrorReaderView 的视觉风格（圆角、间距、阴影、布局方向）。
- 移除 EmptyReaderView 和 ErrorReaderView 的顶部图标容器，减少不必要的空间占用。
- 修复工具栏三区布局：使用 Stack + Align/Positioned 实现左/中/右绝对定位，中间页码导航在窗口正中央。
- 修复翻页导航栏圆角不一致问题，内部按钮不再自带独立圆角背景，由外层 ClipRRect 统一裁剪。
- 缩短翻页导航栏页码与总页码的间距。
- 修复 macOS Dock 图标偏大问题，添加 10% 内边距使内容区占画布 80%。
- 替换全部平台应用图标。
- 适宽按钮改为图标（`HugeIcons.strokeRounded2ndBracketSquare`），移至单双页切换按钮旁。
- 工具栏页码、缩放、适宽、100% 按钮仅在 PDF 成功渲染后显示。
- 自定义 macOS 窗口标题栏背景色，与 app 深色主题统一。
- Added repository-level contributor guide in `AGENTS.md`.
- Replaced the placeholder README with project-specific setup and feature documentation.
- Refactored PDF file picking into a dedicated `PdfFilePicker` service.
- Extracted outline flattening into `PdfOutlineMapper` to reduce `HomeController` responsibility.
- Centralized recent-file lookup and persistence helpers in `PdfReaderStore`.
- Extracted keyboard shortcut wiring into `ReaderShortcuts`.
- Removed duplicated sidebar item interaction styling through a shared `_SidebarListItem`.
