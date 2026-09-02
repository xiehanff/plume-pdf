# 后续计划

> 基线：Plume PDF `v0.1.0`，更新于 2026-09-02。

v0.1.0 已完成移动端基础、AI 框选、流式体验、状态源/生命周期收敛、DeepSeek transport 清理和桌面/Android 自动发布链路。以下只保留当前仍有效的事项。

## P0 — Android 正式分发与局域网安全

- [ ] Android 正式签名：使用 production keystore，不再让 `release` buildType 指向 debug signing；通过 GitHub Secrets 注入签名材料，keystore/密码不得进入仓库。
- [ ] WiFi 传书增加随机 session/upload token；当前服务只应在受信任局域网使用，知道临时地址的同网设备理论上可以尝试上传。
- [ ] 正式移动分发前统一 Android application label、Application ID 与版本发布策略。
- [ ] Release 资产增加 checksum（如 SHA-256）或签名清单，便于自托管下载后校验完整性。

## P1 — 多模型 / Provider 架构

当前保留 `AiModelRegistry` / `AiModelConfig`，但生产调用仍直接依赖 `DeepSeekService`。后续接入其他模型时再抽象，不为了当前单 Provider 过早增加层级。

- [ ] 抽象 `AiBackend` / `AiProvider` 接口，让 `AiAgentSession` 不再直接依赖 `DeepSeekService`。

  ```dart
  abstract interface class AiBackend {
    Stream<AiStreamEvent> runToolAction(...);
    Stream<AiStreamEvent> chat(...);
  }

  class DeepSeekBackend implements AiBackend { ... }
  ```

- [ ] 引入统一 `sealed class AiStreamEvent`，逐步替代 provider-specific chunk：
  1. `TextDelta`
  2. `ReasoningDelta`
  3. `SuggestionsEvent`
  4. 未来需要时再加入结构化 UI / GenUI surface event
- [ ] 模型配置与 provider 能力绑定：vision、reasoning、context window、streaming、max output 等能力由 registry 描述，而不是散落在 UI。
- [ ] API Key / endpoint 设置改为 provider 维度，避免后续多模型继续增加 DeepSeek 专用字段。

## P1 — AI 正确性测试继续补齐

- [ ] `runToolAction`: stream error → history 不变
- [ ] `runToolAction`: empty content → history 不变
- [ ] vision image 正确进入 provider 请求
- [ ] preview delta 顺序与终态 flush 正确
- [ ] `sendChat`: 失败/空响应时回滚 user 消息
- [ ] provider 切换后的 history / image attachment 兼容策略

## P2 — 成本与上下文控制

- [ ] `AiAgentSession.history` 改为不可变视图（`List.unmodifiable` / `UnmodifiableListView`）。
- [ ] 新增 `PdfAiContextCache`：同一 PDF 的页面文本只 extract 一次，减少重复 `loadText` 与重复 token。
- [ ] 页面正文增加 `maxPageCharacters` 字符预算（例如 8K/12K）；更远期再做 relevant chunk retrieval。
- [ ] 对跨页选区增加最大页数 / 最大截图像素预算，避免极端大选区生成过大的合并图片。
- [ ] 对长历史加入 provider-aware token budget / summary policy。

## P2 — 发布体验

- [ ] GitHub Release 页面补充平台安装提示、系统要求和常见报错入口。
- [ ] Windows/macOS/Linux 安装包增加自动 smoke test（能启动、资源存在、版本号正确）。
- [ ] Android production signing 完成后，再评估 Play Store / F-Droid / 自托管更新渠道。

## 暂缓 — iOS

当前没有构建/发布 iOS App 的计划，因此：

- `ios/` 工程继续保留，避免未来重新生成 Runner
- Mobile CI 不执行 `flutter build ios --simulator`
- GitHub Release 不生成 IPA
- 暂不投入 Team / provisioning / export options / signing 自动化

未来重新启动 iOS 发布时，再恢复 simulator/release 验证和正式签名链路。

## v0.1.0 已完成的关键项

### 阅读 / 移动

- [x] Android/iOS Mobile Shell 与 SafeArea
- [x] Viewer 级唯一框选与跨页 `PdfAiSelectionRegion`
- [x] 屏幕空间感知的 AI 工具条定位与 20% 中心兜底
- [x] WiFi 传书基础实现
- [x] Android arm64-only CI / release APK

### AI / 隐私

- [x] 删除发送给模型的本机 `directory` / `fileSize`
- [x] PDF 正文使用不可信文档边界与 `<document_context>` 隔离
- [x] 请求代数阻止旧 stream 覆盖新会话 UI / history
- [x] AI stream preview 合并与 timer 清理
- [x] 用户阅读历史时延后流式昂贵 rebuild
- [x] 视觉 fallback 只在明确 image/multimodal 能力拒绝时重试文本

### 结构清理

- [x] 快捷键输入路径收敛为 `CallbackShortcuts + Focus`
- [x] 删除 `StreamingAiSidebarController`，流式刷新策略合入 `AiSidebarController`
- [x] `AiSidebarController` 统一由 `HomeController` 创建/销毁
- [x] 页码使用 `onPageChanged` 单一事件源，Controller listener 只负责 zoom
- [x] 旧 Viewer/page/outline 异步结果增加 source/generation 保护
- [x] 阅读进度 debounce 使用 file/page 快照
- [x] 删除 Genkit runtime 与 `genkit` / `genkit_openai` 依赖
- [x] DeepSeek 收敛为单一 OpenAI-compatible HTTP/SSE transport

### CI / Release

- [x] Mobile CI：Ubuntu + Test + Analyze + Android arm64 + ABI 校验
- [x] Linux DEB + RPM 自动打包
- [x] Windows Inno Setup EXE 自动打包
- [x] macOS DMG 自动打包
- [x] 发布提交自动创建 `v*` tag
- [x] Android arm64 release APK + GitHub Release 聚合上传
