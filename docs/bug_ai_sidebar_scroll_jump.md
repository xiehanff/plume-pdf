# Bug 报告：AI 对话区流式输出与滚动跳动

> **状态：已修复。v0.1.0 已把相关流式刷新策略收敛到 `AiSidebarController`。**
>
> 本文保留问题演进与最终行为契约，避免未来升级 Flutter、改聊天列表或接入新模型 Provider 时重新引入“用户阅读历史被推走”或“贴底画面晚一帧跳动”。

## 1. 原始问题

AI 流式输出会持续增加最后一个模型消息的高度。早期实现依赖 post-frame `jumpTo(maxScrollExtent)` 保持贴底，在以下场景容易出问题：

- 鼠标滚轮/触摸上滑阅读历史时被自动拉回底部
- 流式气泡变高后，scroll position 数值已修正，但当前 frame 仍按旧 offset 绘制，下一帧出现闪烁/跳动
- 每个 stream chunk 都触发 GetBuilder + Markdown rebuild，长回答越到后面成本越高
- 为了解决 rebuild 又曾引入独立 `StreamingAiSidebarController`，导致 AI Sidebar 同时存在两个 Controller 生命周期和额外同步路径

## 2. v0.1.0 当前实现

### 2.1 FollowTailScrollController

当前贴底核心不依赖每个 token 的 post-frame jump。

`FollowTailScrollPosition.correctForNewDimensions(...)` 在内容尺寸增长、且当前处于 follow-tail 状态时：

```text
correctPixels(newDimensions.maxScrollExtent)
return false
```

返回 `false` 会让 viewport 在**当前 frame 重新 layout**。因此不仅 `pixels` 数值正确，最新气泡也必须在同一 frame 被画进 viewport。

这条行为有 render-level 回归断言保护；升级 Flutter 时不要删除该测试。

### 2.2 用户阅读历史时不强制跟随

`AiSidebarController` 维护当前滚动意图：

```text
followingTail
userControlled
```

用户主动离开底部后：

- 新 token 不修改用户阅读位置
- 不因为每个 preview 都强制刷新整块昂贵 Markdown
- Controller 记录存在待刷新的 streaming state

用户重新进入底部阈值后：

- flush 最新状态
- 恢复 follow-tail
- 后续流式增长继续同帧贴底

### 2.3 独立 Streaming Controller 已删除

v0.1.0 删除：

```text
lib/app/modules/home/controllers/streaming_ai_sidebar_controller.dart
```

原来“用户离开底部时延后流式 rebuild”的职责直接合入 `AiSidebarController`，核心状态类似：

```text
_hasDeferredStreamingUpdate
```

这样生产环境只剩一个 AI Sidebar Controller：

```text
HomeController
    ↓ create / own / delete
AiSidebarController
    ├─ 输入框与设置资源
    ├─ 会话 UI 状态
    ├─ sidebar resize
    ├─ scroll intent
    ├─ deferred streaming rebuild
    └─ FollowTailScrollController
```

`MobileAiView` 不再自行创建 Controller；Debug Gallery 使用独立 tag，不会删除 Home 正在使用的实例。

### 2.4 Preview 合并

`AiAgentSession` 不把每个原始 SSE chunk 都直接推到 UI，而是将 preview 合并到约 40 ms 的节奏。

请求结束、异常、取消或 generation 失效时必须清理 pending timer，避免旧 preview 在终态后再次写回。

### 2.5 Markdown 流式成本控制

- 未闭合 code fence：暂时按轻量文本处理，闭合后再进入完整高亮
- reasoning 折叠态：避免不必要的完整 Markdown 成本
- reasoning 展开态：再使用完整 Markdown
- 用户离开底部后：延后昂贵 streaming rebuild，但 complete/error 终态不能被延后

## 3. 必须保持的行为契约

```text
处于底部 + stream 增长
→ 同帧保持贴底
→ 最新内容当前帧可见
→ 不闪烁

用户上滚阅读历史
→ 新 token 不改变阅读 offset
→ 不强制刷新昂贵 Markdown 区

用户回到底部
→ flush 最新流式状态
→ 恢复自动跟随

请求结束 / 错误 / 取消
→ pending preview 不得晚写
→ 最终状态必须立即可见
```

## 4. 回归测试重点

当前相关测试重点包括：

- `test/ai_sidebar_stream_scroll_test.dart`
  - follow-tail
  - same-frame render assertion
  - 历史阅读时不被推走
- `test/streaming_ai_sidebar_controller_test.dart`
  - 文件名保留历史名称，但测试对象已经是统一后的 `AiSidebarController`
  - 离开底部时延迟 rebuild
  - 返回底部 flush
  - terminal state 立即刷新
- `test/ai_agent_session_test.dart`
  - preview 合并
  - timer cleanup
  - stale generation / request 行为

## 5. 修改这部分代码时不要做什么

不要简单恢复：

```dart
WidgetsBinding.instance.addPostFrameCallback((_) {
  scrollController.jumpTo(scrollController.position.maxScrollExtent);
});
```

它会把“layout 内纠正”重新退化成“下一帧视觉跳动”。

不要重新创建第二个 streaming-only Controller。滚动意图、输入资源、会话展示和 rebuild 策略属于同一个 Sidebar UI 生命周期，拆成两个 GetX Controller 会重新引入 owner/sync 问题。

也不要为了降低 rebuild 丢掉终态刷新。性能优化只能合并/延后 preview，不能吞掉 complete/error/cancel。

## 6. 相关文件

- `lib/app/modules/home/controllers/ai_sidebar_controller.dart`
- `lib/app/modules/home/services/ai_agent_session.dart`
- `lib/app/modules/home/views/widgets/ai_sidebar.dart`
- `test/ai_sidebar_stream_scroll_test.dart`
- `test/streaming_ai_sidebar_controller_test.dart`
- `test/ai_agent_session_test.dart`

## 7. 版本基线

本文当前对应 Plume PDF `v0.1.0`。后续若 Flutter 的 `ScrollPosition.correctForNewDimensions` 语义发生变化，应优先让 render-level regression test 验证实际画面，而不是只检查 `pixels == maxScrollExtent`。
