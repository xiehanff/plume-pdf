# Bug 报告：AI 对话区 scrollbar 在滚轮滚动时瞬间跳到底部

## Bug 描述

**现象**：在 AI 对话区域，当用户使用鼠标滚轮滚动查看历史对话时，scrollbar 会在某个 offset 瞬间跳动到底部，打断用户的滚动操作。

**触发条件**：
- AI 对话区域有消息（流式输出中或输出已结束）
- 用户使用鼠标滚轮（mouse wheel）上滑查看历史对话
- 用户从底部附近开始滚动时尤为明显

**复现步骤**：
1. 启动应用，打开任意 PDF，触发 AI 翻译/解释动作
2. 等待 AI 流式输出（或输出结束）
3. 在对话区域使用鼠标滚轮上滑
4. 观察 scrollbar 在某个位置突然跳到底部

---

## 涉及文件

- **唯一需要修改的文件**：`lib/app/modules/home/views/widgets/ai_sidebar.dart`

---

## 根因分析

### 核心问题：鼠标滚轮事件不触发 `UserScrollNotification`

Flutter 中 `UserScrollNotification` 仅在 PointerDown/Move（触摸/拖拽）手势识别时触发。
鼠标滚轮事件通过 `ScrollPosition.pointerScroll(delta)` 直接更新 pixels，**不创建 DragScrollActivity**，因此**不触发 `UserScrollNotification`**。

### 当前代码的缺陷

文件：`lib/app/modules/home/views/widgets/ai_sidebar.dart`

#### 缺陷 1：仅依赖 `UserScrollNotification` 设置 `_userIsScrolling`

位置：`_handleScrollNotification` 方法

```dart
bool _handleScrollNotification(ScrollNotification notification) {
  if (notification is UserScrollNotification) {
    _userIsScrolling = true;   // ← 鼠标滚轮滚动时此分支不触发
    _userIsAtBottom = false;
  } else if (notification is ScrollEndNotification) {
    _userIsScrolling = false;
    ...
  }
  return false;
}
```

→ 鼠标滚轮滚动时 `_userIsScrolling` 保持 `false`。

#### 缺陷 2：`_onScrollChanged` 因此错误恢复 `_userIsAtBottom = true`

位置：`_onScrollChanged` 方法（ScrollController listener）

```dart
void _onScrollChanged() {
  if (!_scrollController.hasClients) return;
  if (_userIsScrolling) return;   // ← 鼠标滚轮时 _userIsScrolling=false，不 return
  final ScrollPosition pos = _scrollController.position;
  final double distance = pos.maxScrollExtent - pos.pixels;
  final bool atBottom = distance <= _kBottomFollowThreshold;  // 阈值=80
  if (atBottom != _userIsAtBottom) {
    _userIsAtBottom = atBottom;  // ← 错误恢复为 true
  }
}
```

→ 用户从底部附近（distance ≤ 80）开始用滚轮上滑时，pixels 减少但仍处于阈值内，`_onScrollChanged` 把 `_userIsAtBottom` 恢复为 `true`。

#### 缺陷 3：PostFrameCallback 中的 `jumpTo` 打断用户滚动

位置：`_scheduleScrollToBottom` + `_maybeScrollToBottom`

```dart
void _scheduleScrollToBottom({bool animated = false}) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted) {
      _maybeScrollToBottom(animated: animated);  // ← _userIsAtBottom=true 时 jumpTo
    }
  });
}

void _maybeScrollToBottom({bool animated = false}) {
  if (!_scrollController.hasClients) return;
  if (!_userIsAtBottom) return;  // ← 此处检查失败，允许 jumpTo
  final ScrollPosition pos = _scrollController.position;
  final double target = pos.maxScrollExtent;
  ...
  _scrollController.jumpTo(target);  // ← 瞬间跳到底部，打断用户滚动
}
```

### 调用 `_scheduleScrollToBottom` 的源头

下列分支都会注册 PostFrameCallback 调用 `_maybeScrollToBottom`：

1. `_syncMessagesFromState` 的 `state.loading && _lastResult == null` 分支
2. `_syncMessagesFromState` 的流式增量分支（`_updateLastAiMessage` 之后）
3. `_replaceLoadingOrAdd` 末尾
4. `_sendMessage` 中
5. `_syncMessagesFromState` 的 actionLabel 新动作分支

流式输出期间，每个 chunk 都会触发上面某个分支，注册 PostFrameCallback。

### 完整时序（bug 触发场景）

```
T0: 流式 chunk N 到来
  → _applyState (HomeController)
  → GetBuilder 重建 AiSidebar
  → _buildMessageList() → _syncMessagesFromState()
  → 进入 result 分支 → _updateLastAiMessage + _scheduleScrollToBottom
  → PostFrameCallback 入队

T1: 用户开始用鼠标滚轮上滑
  → PointerScrollEvent (不触发 UserScrollNotification)
  → ScrollPosition.pointerScroll(delta) 更新 pixels
  → _scrollController listener 触发 _onScrollChanged
  → _userIsScrolling = false（UserScrollNotification 没触发过）
  → 检查 distance，若 ≤ 80 → _userIsAtBottom = true

T2: 帧结束
  → PostFrameCallback 执行 _maybeScrollToBottom
  → _userIsAtBottom = true → 调用 jumpTo(maxScrollExtent)
  → pixels 瞬间跳到 maxScrollExtent
  → 打断用户滚动 ← BUG 现象
```

---

## 修复方案

### 方案：用 `Listener.onPointerSignal` 捕获鼠标滚轮事件

在 `_buildMessageList` 的 `NotificationListener` 内层包一层 `Listener`，监听 `PointerSignalEvent`：

```dart
return NotificationListener<ScrollNotification>(
  onNotification: _handleScrollNotification,
  child: Listener(
    onPointerSignal: _handlePointerSignal,  // 新增
    child: ListView.builder(
      controller: _scrollController,
      ...
    ),
  ),
);
```

新增方法：

```dart
void _handlePointerSignal(PointerSignalEvent event) {
  if (event is PointerScrollEvent) {
    _userIsScrolling = true;
    _userIsAtBottom = false;
  }
}
```

需要在文件顶部添加导入：

```dart
import 'package:flutter/gestures.dart' show PointerSignalEvent, PointerScrollEvent;
```

### 修复后的工作时序

```
T0: 用户开始用鼠标滚轮上滑
  → PointerScrollEvent
  → _handlePointerSignal → _userIsScrolling = true, _userIsAtBottom = false ✓
  → pixels 变化
  → _onScrollChanged → _userIsScrolling=true → return ✓

T1-Tn: 用户持续滚动
  → 每帧 PointerScrollEvent → _userIsScrolling 保持 true ✓
  → 任何 PostFrameCallback 执行 _maybeScrollToBottom
  → _userIsAtBottom=false → return ✓ 不 jumpTo

Tn+1: 用户停下，Flutter 创建 BallisticScrollActivity（惯性）
  → pixels 继续变化
  → _onScrollChanged → _userIsScrolling=true → return ✓

Tn+k: 惯性结束 → ScrollEndNotification
  → _userIsScrolling = false
  → 检查 distance 决定是否恢复跟随
  → 若 distance > 80 → _userIsAtBottom = false（继续禁用跟随）
  → 若 distance ≤ 80 → _userIsAtBottom = true（恢复跟随）
```

---

## 验证方法

1. **流式输出期间**用鼠标滚轮上滑查看历史 → scrollbar 不应跳到底部
2. **流式输出结束后**用鼠标滚轮上滑 → 同样不应跳到底部
3. 上滑后**回到底部附近**（distance ≤ 80）→ 应恢复自动跟随（新消息到达时 jumpTo 到底部）
4. 从底部附近开始滚轮滚动 → 不应被打断（这是原 bug 最容易复现场景）

---

## 相关文件路径

- 主修复文件：`lib/app/modules/home/views/widgets/ai_sidebar.dart`
- 触发状态变化的 controller：`lib/app/modules/home/controllers/home_controller_ai_session.dart`
- 父级 widget：`lib/app/modules/home/views/home_view.dart`（包裹 AiSidebar 的 GetBuilder）

---

## 备注

- 本 bug 是滚动跟随逻辑的副作用，原始代码意图是"自动跟随到底部"
- 阈值 `_kBottomFollowThreshold = 80` 在鼠标滚轮场景下不足以正确判断用户意图
- 通过 `PointerScrollEvent` 显式标记用户主动滚动是最直接的修复方式
