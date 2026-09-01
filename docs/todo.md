# 后续计划

更新：2026-09-01。

移动端 Android/iOS Shell、跨页 AI 框选、WiFi 传书、Mobile CI 和 tag-only Android APK 已完成并准备进入 `main`。以下只保留仍然有效的后续事项。

## P0 — 正式移动分发前

- [ ] Android 正式签名：使用 production keystore，不再让 `release` buildType 指向 debug signing；通过 GitHub Secrets 注入签名材料，避免 keystore/密码进入仓库。
- [ ] iOS 正式签名与真机 Release：补齐 Team / Bundle ID / provisioning / export options，并增加真实 iOS release/IPA 验证链路。
- [ ] WiFi 传书增加随机 session/upload token；当前服务只应在受信任局域网使用，知道临时地址的同网设备理论上可以尝试上传。
- [ ] 移动端正式发行前统一 Android application label、iOS display name、Bundle/Application ID 与版本发布策略。

## P1 — AI 架构准备

- [ ] 抽象 `AiBackend` 接口，解除 `AiAgentSession` 对 `DeepSeekService` 的直接依赖。

  ```dart
  abstract interface class AiBackend {
    Stream<AiStreamEvent> runToolAction(...);
    Stream<AiStreamEvent> chat(...);
  }

  class DeepSeekBackend implements AiBackend { ... }
  ```

  后续 GenUI / 多模型（Gemini 等）通过 Backend 实现接入，避免实验性 SDK 污染核心会话层。

- [ ] 引入 `sealed class AiStreamEvent`，按阶段迁移：
  1. `AiBackend` → 统一事件流
  2. `TextDelta` / `ReasoningDelta` / `SuggestionsEvent` 替代当前 preview 回调
  3. `UiSurfaceEvent` → GenUI Surface

- [ ] 继续补 `AiAgentSession` 失败分支测试：
  - `runToolAction`: stream error → history 不变
  - empty content → history 不变
  - vision image 正确进入请求
  - preview 顺序正确
  - `sendChat`: 失败/空响应回滚 user 消息

## P2 — 成本与封装

- [ ] `AiAgentSession.history` 改为不可变视图（`List.unmodifiable` / `UnmodifiableListView`）。
- [ ] 新增 `PdfAiContextCache`：同一 PDF 的页面文本只 extract 一次，避免每轮对话重复 `loadText` 与重复 token。
- [ ] 页面正文增加 `maxPageCharacters` 字符预算（例如 8K/12K）；更远期再做 relevant chunk retrieval。
- [ ] 对跨页选区增加最大页数/最大截图像素预算，避免极端超大框选生成过大的合并图片。

## 已完成的关键项

- [x] 删除发送给 DeepSeek 的本机 `directory` / `fileSize`
- [x] PDF 正文使用不可信文档边界与 `<document_context>` 隔离
- [x] 请求代数阻止旧 stream 覆盖新会话 UI / history
- [x] AI stream preview 合并与 timer 清理
- [x] 用户阅读历史时延后流式昂贵 rebuild
- [x] Viewer 级唯一框选与跨页 `PdfAiSelectionRegion`
- [x] 屏幕空间感知的 AI 工具条定位与 20% 中心兜底
- [x] Android/iOS Mobile Shell 与 SafeArea
- [x] WiFi 传书基础实现
- [x] Mobile CI
- [x] `v*` tag-only Android release-mode APK + GitHub Release 聚合
