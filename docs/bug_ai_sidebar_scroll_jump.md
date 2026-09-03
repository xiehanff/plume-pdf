# Bug 报告：AI 对话区流式输出与滚动跳动

> **状态：已修复。v0.1.2 在既有滚动稳定性基础上补齐了“用户主动停止流式生成”的完整取消链路。**
>
> 本文保留问题演进与最终行为契约，避免未来升级 Flutter、改聊天列表或接入新模型 Provider 时重新引入“用户阅读历史被推走”“贴底画面晚一帧跳动”或“停止后仍继续消费 token”等问题。

## 1. 原始问题

AI 流式输出会持续增加最后一个模型消息的高度。早期实现依赖 post-frame `jumpTo(maxScrollExtent)` 保持贴底，在以下场景容易出问题：

- 鼠标滚轮/触摸上滑阅读历史时被自动拉回底部
- 流式气泡变高后，scroll position 数值已修正，但当前 frame 仍按旧 offset 绘制，下一帧出现闪烁/跳动
- 每个 stream chunk 都触发 GetBuilder + Markdown rebuild，长回答越到后面成本越高
- 为了解决 rebuild 又曾引入独立 `StreamingAiSidebarController`，导致 AI Sidebar 同时存在两个 Controller 生命周期和额外同步路径
- 生成期间发送按钮过去只能 disabled，用户无法主动终止已经不需要的长回答

## 2. v0.1.2 当前实现

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

生产环境只保留一个 AI Sidebar Controller：

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

### 2.5 主动停止生成

v0.1.2 把发送按钮的 loading 状态从“不可点击”改成“停止生成”。

```text
正常
发送按钮
   ↓ send
loading = true
   ↓
停止按钮 ■
   ↓ click
HomeController.stopAiResponse()
   ↓
AiAgentSession.stopActiveStream()
   ↓
StreamSubscription.cancel()
   ↓
停止继续消费 DeepSeek SSE
```

停止不是只忽略后续 UI token，而是真正取消当前底层 stream subscription。对于 `DeepSeekService` 内部创建的 HTTP client，取消会使异步生成器退出，并进入 `finally -> client.close()` 的资源释放路径。

停止语义：

- 已有部分正文 / reasoning：保留当前内容，并把 loading 收尾为完成态
- 第一个 token 尚未返回：移除空 AI loading 占位，不留下空气泡
- 仍在 PDF/document context 准备阶段：复用 `_aiActionId` 让请求失效，不再进入模型 stream
- 停止期间 transport 恰好报错：用户主动停止语义优先，不用错误态覆盖已停止 UI
- 新建会话 / `HomeController.onClose`：主动取消正在进行的 stream

### 2.6 Markdown 流式成本控制

- 未闭合 code fence：暂时按轻量文本处理，闭合后再进入完整高亮
- reasoning 折叠态：避免不必要的完整 Markdown 成本
- reasoning 展开态：再使用完整 Markdown
- 用户离开底部后：延后昂贵 streaming rebuild，但 complete/error/stop 终态不能被延后

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

用户点击停止
→ 立即取消 active StreamSubscription
→ 不再追加 token
→ 保留已收到的部分回答
→ 空 loading 占位被清理
→ 发送按钮立即恢复

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
  - 主动停止实际触发 subscription cancel
  - 停止后保留已收到的部分回答
- `test/chat_input_bar_test.dart`
  - loading 时发送按钮切换为可点击停止按钮
- `test/ai_sidebar_stop_state_test.dart`
  - 无正文停止时移除空 loading
  - 已有部分正文停止时保留内容并结束 loading

## 5. 修改这部分代码时不要做什么

不要简单恢复：

```dart
WidgetsBinding.instance.addPostFrameCallback((_) {
  scrollController.jumpTo(scrollController.position.maxScrollExtent);
});
```

它会把“layout 内纠正”重新退化成“下一帧视觉跳动”。

不要重新创建第二个 streaming-only Controller。滚动意图、输入资源、会话展示和 rebuild 策略属于同一个 Sidebar UI 生命周期，拆成两个 GetX Controller 会重新引入 owner/sync 问题。

不要把“停止生成”实现成只递增 generation / 忽略 UI callback。已经进入网络 stream 后必须取消 subscription，否则模型响应仍可能继续下载并消耗资源。

也不要为了降低 rebuild 丢掉终态刷新。性能优化只能合并/延后 preview，不能吞掉 complete/error/stop。

## 6. 相关文件

- `lib/app/modules/home/controllers/ai_sidebar_controller.dart`
- `lib/app/modules/home/controllers/home_controller_ai_session.dart`
- `lib/app/modules/home/services/ai_agent_session.dart`
- `lib/app/modules/home/views/widgets/ai_sidebar.dart`
- `lib/app/modules/home/views/widgets/chat_input_bar.dart`
- `test/ai_sidebar_stream_scroll_test.dart`
- `test/streaming_ai_sidebar_controller_test.dart`
- `test/ai_agent_session_test.dart`
- `test/ai_sidebar_stop_state_test.dart`
- `test/chat_input_bar_test.dart`

## 7. 版本基线

本文当前对应 Plume PDF `v0.1.2`，更新于 2026-09-03。后续若 Flutter 的 `ScrollPosition.correctForNewDimensions` 或 Dart Stream cancellation 语义发生变化，应优先让 regression test 验证实际画面与真实 subscription 生命周期，而不是只检查状态字段。
