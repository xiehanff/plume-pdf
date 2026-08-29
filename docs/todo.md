# 后续计划

来源:2026-08-30 架构评审。0.0.19 已完成其中两个 P0 与 actionId 竞态守卫
(删除 directory/fileSize 隐私字段、PDF 正文加不可信边界与 `<document_context>`
分隔、请求代数防旧流覆盖 UI 与污染历史),并同步了 msix_version。
以下为剩余待办。

## P1 — 架构准备(接 GenUI 前完成)

- [ ] 抽象 `AiBackend` 接口,解除 `AiAgentSession` 对 `DeepSeekService` 的直接依赖
  ```dart
  abstract interface class AiBackend {
    Stream<AiStreamEvent> runToolAction(...);
    Stream<AiStreamEvent> chat(...);
  }

  class DeepSeekBackend implements AiBackend { ... }
  ```
  之后 GenUI / 多模型(Gemini 等)以 Backend 实现接入,核心架构不被实验性 SDK 污染。
- [ ] 引入 `sealed class AiStreamEvent`,按阶段迁移:
  1. `AiBackend` → 统一事件流
  2. `TextDelta` / `ReasoningDelta` / `SuggestionsEvent` 替代 `onPreview(text, reasoning)` 回调
  3. `UiSurfaceEvent` → GenUI Surface(此时 `followUpSuggestions`、`ComparisonCard` 等
     才从 `AiResponseParser` 自制协议迁到结构化 UI)
- [ ] 补齐 `AiAgentSession` 测试(现有 happy-path 与 clear-during-stream 之外的分支):
  - `runToolAction`:stream error → history 不变;empty content → history 不变;
    vision → image 正确写入;preview 顺序正确
  - `sendChat`:失败回滚 user 消息;空响应回滚

## P2 — 成本与封装

- [ ] `AiAgentSession.history` 改为不可变视图(`List.unmodifiable` /
  `UnmodifiableListView`),外部不得绕过会话层修改历史
- [ ] 新增 `PdfAiContextCache`:同一 PDF 的页面文本只 extract 一次
  (documentId → page → text),避免每轮对话重复 `loadText` 与重复发送相同 token
- [ ] 页面正文增加字符预算 `maxPageCharacters`(如 8K/12K),超长截断;
  更远期再做 relevant chunk retrieval,暂不上向量数据库
