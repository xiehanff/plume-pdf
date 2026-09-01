# Bug 报告：AI 对话区流式输出与滚动跳动

> **状态：已修复，并在移动端合并前继续补强。**
>
> 本文保留问题演进与最终约束，避免未来升级 Flutter 或重构聊天列表时重新引入“用户阅读历史被推走”或“贴底画面晚一帧跳动”。

## 1. 原始问题

AI 流式输出会持续增加最后一个模型消息的高度。早期实现依赖 post-frame `jumpTo(maxScrollExtent)` 保持贴底，在以下场景容易出问题：

- 鼠标滚轮上滑阅读历史时被自动拉回底部
- 流式气泡变高后，scroll position 数值已修正，但当前 frame 仍按旧 offset 绘制，下一帧出现闪烁/跳动
- 每个 stream chunk 都触发多次 GetBuilder + Markdown rebuild，长回答越到后面成本越高

## 2. 当前实现

### 2.1 FollowTailScrollController

当前贴底核心不再依赖每个 token 的 post-frame jump。

`FollowTailScrollPosition.correctForNewDimensions(...)` 在内容尺寸增长时，如果当前处于 follow-tail 状态，会：

```text
correctPixels(newDimensions.maxScrollExtent)
return false
```

返回 `false` 的意义是让 viewport **当前 frame 重新 layout**。因此不仅 pixels 正确，最新气泡也必须在同一 frame 被画在 viewport 内。

这条行为有 render-level 回归断言保护；升级 Flutter 时不要删除该测试。

### 2.2 用户阅读历史时不强制跟随

当用户主动离开底部区域后，新的 token 不应该改变阅读位置。

现在由 AI Sidebar controller/scroll 状态决定是否处于 follow-tail。用户回到底部阈值后才恢复自动跟随。

### 2.3 StreamingAiSidebarController

模型仍在流式输出、但用户正在历史区域阅读时，controller 会延后高频 preview 导致的昂贵 rebuild。

恢复刷新条件包括：

- 用户滚回底部
- 请求进入完成状态
- 请求进入错误状态
- 其他需要立即同步的终态

因此“保持历史阅读位置”和“降低 Markdown 重解析成本”使用同一个滚动意图信号。

### 2.4 Preview 合并

`AiAgentSession` 不再把每个原始 stream chunk 都直接推到 UI，而是将 preview 合并到约 40 ms 的节奏。

请求结束、异常或取消时必须清理 pending timer，避免旧 preview 在终态后再次写回。

### 2.5 Markdown 流式成本控制

- 未闭合代码 fence：暂时以纯文本显示，闭合后再进入完整高亮
- reasoning 折叠态：使用轻量文本
- reasoning 展开态：再使用 `GptMarkdown`

## 3. 必须保持的行为契约

```text
处于底部 + stream 增长
→ 同帧保持贴底
→ 不闪烁

用户上滚阅读历史
→ 新 token 不改变阅读 offset
→ 不强制 rebuild 整个昂贵 Markdown 区

用户回到底部
→ flush 最新流式状态
→ 后续继续自动跟随

请求结束 / 错误
→ 最终状态必须立即可见
```

## 4. 回归测试重点

相关测试包括：

- `test/ai_sidebar_stream_scroll_test.dart`
  - follow-tail
  - same-frame render assertion
  - 历史阅读时不被推走
- `test/streaming_ai_sidebar_controller_test.dart`
  - 离开底部时延迟 rebuild
  - 返回底部 flush
  - terminal state 立即刷新
- `test/ai_agent_session_test.dart`
  - preview 合并
  - timer cleanup / stale request 行为

## 5. 修改这部分代码时的注意事项

不要简单恢复以下模式：

```dart
WidgetsBinding.instance.addPostFrameCallback((_) {
  scrollController.jumpTo(scrollController.position.maxScrollExtent);
});
```

它容易把“layout 后纠正”重新变成“下一帧视觉跳动”。

也不要为了减少 rebuild 而丢掉终态刷新；性能优化只能合并/延后 preview，不能吞掉 complete/error。

## 6. 相关文件

- `lib/app/modules/home/controllers/ai_sidebar_controller.dart`
- `lib/app/modules/home/controllers/streaming_ai_sidebar_controller.dart`
- `lib/app/modules/home/services/ai_agent_session.dart`
- `lib/app/modules/home/views/widgets/ai_sidebar.dart`
- `test/ai_sidebar_stream_scroll_test.dart`
- `test/streaming_ai_sidebar_controller_test.dart`
