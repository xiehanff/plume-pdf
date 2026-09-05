part of 'home_controller.dart';

/// PDF AI orchestration.
///
/// Home owns only PDF/OCR preparation, selection lifecycle and app-level
/// settings. Generic conversation presentation, streaming state, Stop/history
/// semantics and follow-up suggestions are owned by [AiChatController] through
/// [PdfAiChatSession].
extension HomeControllerAiSession on HomeController {
  /// Whether PDF/OCR preparation started by this action is still current.
  bool _isCurrentAiAction(int actionId) => actionId == _aiActionId;

  void toggleAiSelectionMode() {
    _applyState(
      state.copyWith(
        aiSelectionMode: !state.aiSelectionMode,
        aiSelection: null,
      ),
    );
  }

  /// 尝试退出 AI 框选模式。
  ///
  /// 返回 true 表示本次 Escape 确实消费了 Reader 状态；普通阅读状态下
  /// 返回 false，让键盘事件继续交给输入框、弹窗等后续控件处理。
  bool exitAiSelectionMode() {
    if (!state.aiSelectionMode && state.aiSelection == null) {
      return false;
    }
    _applyState(state.copyWith(aiSelectionMode: false, aiSelection: null));
    return true;
  }

  /// Selection lifecycle 只描述“当前框选是什么”。
  ///
  /// 框选开始、变化、取消以及 Overlay 因 viewport/focus 重置 selection，
  /// 都不能结束正在运行的 AI Turn，也不能清理模型输出。只有明确的 AI
  /// 动作、停止、新会话、切文档等入口才有资格改变 AI request/session
  /// 生命周期。
  void onAiSelectionChanged(PdfAiSelection? selection) {
    _applyState(state.copyWith(aiSelection: selection));
  }

  void updateAiApiKey(String apiKey) {
    _applyState(
      state.copyWith(aiPanelState: state.aiPanelState.copyWith(apiKey: apiKey)),
    );
  }

  Future<void> saveAiApiKey() async {
    await _deepSeekSettingsStore.saveApiKey(state.aiPanelState.apiKey);
    _applyState(
      state.copyWith(
        aiPanelState: state.aiPanelState.copyWith(errorMessage: null),
      ),
    );
  }

  /// 新建 AI 会话：Package Controller 统一清空 transport history 与消息 UI；
  /// Home 只递增兼容 sessionId 并清掉尚未移除的旧 panel 字段。
  void startNewAiSession() {
    _invalidateAiWork();
    final int nextSessionId = _aiSessionId + 1;
    _aiSessionId = nextSessionId;
    _applyState(
      state.copyWith(
        aiPanelState: state.aiPanelState.copyWith(
          sessionId: nextSessionId,
          loading: false,
          actionId: null,
          actionLabel: null,
          actionSelectionText: null,
          actionSelectionImage: null,
          result: null,
          reasoning: null,
          followUpSuggestions: const <String>[],
          errorMessage: null,
        ),
      ),
    );
  }

  /// Stops either Home-side PDF/OCR preflight or Package-owned preparation /
  /// transport immediately. Partial model output is finalized by
  /// [AiChatController] and remains visible.
  void stopAiResponse() {
    final bool preparingPdfContext = state.aiPanelState.loading;
    final bool generating = _aiAgentSession.isGenerating;
    if (!preparingPdfContext && !generating) {
      return;
    }

    _aiActionId++;
    if (generating) {
      _aiAgentSession.stopActiveStream();
    }

    _applyState(
      state.copyWith(
        aiPanelState: state.aiPanelState.copyWith(
          loading: false,
          actionId: null,
          actionLabel: null,
          actionSelectionText: null,
          actionSelectionImage: null,
          result: null,
          reasoning: null,
          followUpSuggestions: const <String>[],
          errorMessage: null,
        ),
      ),
    );
  }

  Future<void> runAiAction(AiToolAction action) async {
    final PdfAiSelection? selection = state.aiSelection;
    if (selection == null) {
      return;
    }

    final int currentActionId = ++_aiActionId;
    // A new PDF tool action is latest-wins from the moment the user clicks it,
    // not only after OCR/screenshot extraction finishes.
    if (_aiAgentSession.isGenerating) {
      _aiAgentSession.stopActiveStream();
    }

    _applyState(
      state.copyWith(
        aiSidebarVisible: true,
        aiPanelState: state.aiPanelState.copyWith(
          loading: true,
          actionId: null,
          actionLabel: null,
          actionSelectionText: null,
          actionSelectionImage: null,
          result: null,
          reasoning: null,
          followUpSuggestions: const <String>[],
          errorMessage: null,
        ),
      ),
    );

    if (state.aiPanelState.apiKey.trim().isEmpty) {
      _finishAiPreflight();
      _aiChatController.presentLocalError(
        message: '请先填写 DeepSeek API Key。',
        stopPrevious: true,
      );
      return;
    }

    try {
      final Uint8List? imageBytes = await _pdfAiContextService
          .extractSelectionImageBytes(selection);
      if (!_isCurrentAiAction(currentActionId)) {
        return;
      }

      final String selectionText = await _pdfAiContextService
          .resolveSelectionText(selection, imageBytes: imageBytes);
      if (!_isCurrentAiAction(currentActionId)) {
        return;
      }

      final AiModelConfig? config = AiModelRegistry.instance.configFor(
        DeepSeekBackend.defaultModel,
      );
      final bool useVision =
          config != null &&
          config.supportsVision &&
          imageBytes != null &&
          imageBytes.isNotEmpty;

      _applyState(
        state.copyWith(
          aiSelection: selectionText.trim().isEmpty
              ? selection
              : selection.copyWith(extractedText: selectionText),
          aiPanelState: state.aiPanelState.copyWith(
            loading: false,
            actionId: null,
            actionLabel: null,
            actionSelectionText: null,
            actionSelectionImage: null,
            result: null,
            reasoning: null,
            followUpSuggestions: const <String>[],
            errorMessage: null,
          ),
        ),
      );

      await _aiAgentSession.runToolAction(
        action: action,
        selectionText: selectionText,
        imageBytes: useVision ? imageBytes : null,
        pageContextProvider: () =>
            _pdfAiContextService.extractPageContext(selection),
      );
    } catch (error, stackTrace) {
      if (!_isCurrentAiAction(currentActionId)) {
        return;
      }
      // Errors after submit are already represented by AiChatController. This
      // branch primarily covers extraction failures that happen before handoff.
      if (!_aiAgentSession.isGenerating &&
          state.aiPanelState.loading) {
        _finishAiPreflight();
        _aiChatController.presentLocalError(
          message: '请求失败：$error',
          stopPrevious: true,
        );
      }
      debugPrint('[plume_pdf] PDF AI action failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> sendAiChat(AiChatInput input) async {
    if (input.isEmpty) {
      return;
    }

    final String trimmedMessage = input.text.trim();
    final String displayText = trimmedMessage.isEmpty && input.image != null
        ? '请分析这张图片。'
        : trimmedMessage;
    if (state.aiPanelState.apiKey.trim().isEmpty) {
      _aiChatController.presentLocalError(
        message: '请先填写 DeepSeek API Key。',
        displayText: displayText,
        displayImageBytes: input.image?.bytes,
      );
      return;
    }

    // Capture the document identity/state at submission time. If the reader
    // switches documents while context extraction is running, clearing the
    // Package Controller invalidates the pending transport before it can start.
    final String? filePath = state.filePath;
    final String? fileName = state.fileName;
    final int currentPage = state.currentPage;
    final List<PdfOutlineEntry> outline = List<PdfOutlineEntry>.of(state.outline);

    try {
      await _aiAgentSession.sendChat(
        input: input,
        documentContextProvider: () => _pdfAiContextService
            .buildDocumentContext(
              filePath: filePath,
              fileName: fileName,
              currentPage: currentPage,
              outline: outline,
              message: trimmedMessage,
            ),
      );
    } catch (error, stackTrace) {
      // AiChatController has already finalized the visible error bubble.
      debugPrint('[plume_pdf] AI chat failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  void _finishAiPreflight() {
    if (!state.aiPanelState.loading) {
      return;
    }
    _applyState(
      state.copyWith(
        aiPanelState: state.aiPanelState.copyWith(
          loading: false,
          actionId: null,
          actionLabel: null,
          actionSelectionText: null,
          actionSelectionImage: null,
          result: null,
          reasoning: null,
          followUpSuggestions: const <String>[],
          errorMessage: null,
        ),
      ),
    );
  }
}
