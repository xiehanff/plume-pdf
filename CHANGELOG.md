# Changelog

## 0.0.11 - 2026-08-03

- macOS 保留原生红黄绿窗口按钮，Linux/Windows 使用自定义窗口控制并支持拖动标题栏。
- 自定义窗口控制按钮统一垂直居中，关闭按钮 hover 背景改为红色，最小化按钮改用 HugeIcons 图标。
- 操作栏右侧功能菜单上下内边距统一，移除操作栏底部分割线。
- 顶部左侧移除重复的文件标题，仅保留侧边栏和打开文件按钮；文件标题继续由底部状态栏展示。
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
