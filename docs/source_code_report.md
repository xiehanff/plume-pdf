# Plume PDF 源码报告

## 1. 项目定位

`plume_pdf` 是一个基于 Flutter + GetX 的桌面 PDF 阅读器 MVP，当前重点运行环境是 macOS。核心能力包括：

- 打开本地 PDF
- 支持 Finder / Dock / 窗口拖拽打开 PDF
- 目录侧边栏
- 最近文件记录
- 翻页 / 跳页 / 缩放
- 单页 / 双页阅读
- 阅读进度持久化
- DeepSeek AI 辅助阅读
- 图片型 PDF OCR 兜底识别

当前不是 Flutter Module，而是独立 Flutter App。

## 2. 项目结构划分

### 根目录

- `lib/`：业务源码
- `macos/`：macOS Runner 与桌面配置
- `test/`：测试
- `docs/`：项目文档
- `README.md`：项目使用说明
- `CHANGELOG.md`：变更记录
- `AGENTS.md`：仓库协作指南

### lib/

- `main.dart`
  - 应用入口
  - 注入全局暗色主题
  - 配置全局去 splash 的 Material 主题

- `app/routes/`
  - `app_pages.dart`：GetX 路由表
  - `app_routes.dart`：路由常量

- `app/modules/home/`
  - 当前唯一业务模块，承担整个阅读器主界面

## 3. Home 模块拆分

### bindings

- `home_binding.dart`
  - 注册 `HomeController`

### controllers

- `home_controller.dart`
  - 阅读器主控制器
  - 负责文件打开、窗口拖拽 / Finder / Dock 打开接入、页面跳转、缩放、快捷键、最近文件加载、阅读状态刷新
  - 当前是主状态编排入口，属于模块内 source of truth

### models

- `pdf_reader_state.dart`
  - 页面状态对象
  - 包含文件路径、页码、缩放、侧边栏开关、双页模式、目录、最近文件、拖拽悬停状态等

- `pdf_outline_entry.dart`
  - 目录项扁平结构

- `pdf_recent_file.dart`
  - 最近文件结构与序列化

### services

- `pdf_file_picker.dart`
  - 文件选择器封装
  - 当前统一走 `file_selector`

- `pdf_outline_mapper.dart`
  - 将 `pdfrx` 的 outline tree 扁平化为 UI 可直接消费的数据

- `pdf_reader_store.dart`
  - 最近文件和阅读进度持久化
  - 基于 `shared_preferences`

- `macos_file_open_service.dart`
  - macOS 原生文件打开桥接
  - 接收 Finder / Dock 传入的文件路径并转发给 Dart 层

### views

- `home_view.dart`
  - 阅读器页面骨架
  - 组合顶部工具栏、左侧目录、中央 PDF 区、底部状态栏
  - 根层集成桌面拖拽接收区和拖入提示层

### views/widgets

- `reader_shortcuts.dart`
  - 页面级快捷键壳层

- `reader_toolbar.dart`
  - 顶部工具栏
  - 包含打开文件、目录开关、单双页切换、翻页、缩放、适宽、100%

- `reader_sidebar.dart`
  - 左侧目录 / 最近文件区域
  - 当有 outline 时显示目录，否则显示最近文件

- `pdfrx_viewer_adapter.dart`
  - `pdfrx` 适配层
  - 负责 viewer 参数、错误回调、双页排版

- `page_status_bar.dart`
  - 底部状态栏

- `empty_reader_view.dart`
  - 空态

- `error_reader_view.dart`
  - 错误态

## 4. 主要状态流

### 打开文件

1. `ReaderToolbar` / 空态按钮 / Finder / Dock / 窗口拖拽 任一入口触发文件打开
2. Flutter 文件选择器或 macOS 原生桥接返回文件路径
3. `HomeController.openFilePath()` 更新 `PdfReaderState`
4. PDF Viewer 重新加载 PDF
5. `PdfReaderStore` 记录最近文件和页码

### 阅读状态更新

1. `pdfrx` 页码变化回调进入 `HomeController.onPageChanged()`
2. 更新当前页码与输入框
3. debounce 后写入最近文件记录

### 目录跳转

1. `ReaderSidebar` 点击目录项
2. `HomeController.jumpToOutlinePage()`
3. 设置选中目录 id
4. 调 `PdfViewerController.goToPage()`

## 5. 平台层说明

### macOS

- `macos/Runner/MainFlutterWindow.swift`
  - 标准 Flutter macOS 窗口初始化
  - 注册 OCR channel 和文件打开 channel

- `macos/Runner/AppDelegate.swift`
  - 处理 `application(_:openFiles:)`
  - 接收 Finder 双击、Dock 拖入、默认打开方式唤起时传入的 PDF 路径

- `macos/Runner/Info.plist`
  - 注册 `com.adobe.pdf` 文档类型
  - 让系统识别 Plume PDF 为可打开 PDF 的应用

当前文件打开能力同时依赖 Flutter 插件和 macOS 原生 openFiles 桥接。

## 6. 测试现状

- `test/widget_test.dart`
  - 校验首次启动空态

- `test/pdf_outline_mapper_test.dart`
  - 校验目录扁平化逻辑

当前测试覆盖偏轻，集中在启动空态和纯逻辑映射。

## 7. 后续 agent 进入仓库建议

1. 先从 `lib/main.dart -> app/routes/app_pages.dart -> home_view.dart -> home_controller.dart` 顺着主链路读
2. 只要涉及 PDF 加载、翻页、缩放，优先看 `home_controller.dart` 和 `pdfrx_viewer_adapter.dart`
3. 只要涉及最近文件或阅读页码持久化，优先看 `pdf_reader_store.dart`
4. 只要涉及目录显示或选中逻辑，优先看 `pdf_outline_mapper.dart`、`pdf_outline_entry.dart`、`reader_sidebar.dart`
5. 改 macOS 文件打开行为前，先确认是“窗口内拖拽”还是“Finder / Dock / 默认打开方式”链路；后者已经接入 `macos/` 原生层

## 8. 当前代码边界

- 当前只有一个 `home` 模块，没有拆分多页面或多 domain
- 主题、颜色和交互样式已经收敛到 `app/theme/app_colors.dart`，但主阅读链路仍主要由 `home` 模块承载
- `HomeController` 仍然是模块内最重的文件，后续若继续重构，优先拆“阅读会话状态编排”和“快捷键处理”
