part of 'home_controller.dart';

/// AI 动作与会话编排：负责状态流转与层间协调。
///
/// 流式累积/历史写入在 [AiAgentSession]（会话层），
/// PDF 选区与文档上下文提取在 [PdfAiContextService]（提取层）。
extension HomeControllerAiSession on HomeController {
  /// 请求发起时捕获的 actionId 是否仍是最新一次：失效的旧请求
  /// 不得再写入面板状态，避免覆盖新请求或新会话的结果。
  bool _isCurrentAiAction(int actionId) => actionId == _aiActionId;

  void toggleAiSelectionMode() {
    _applyState(
      state.copyWith(
        aiSelectionMode: !state.aiSelectionMode,
        aiSelection: null,
      ),
    );
  }

  void exitAiSelectionMode() {
    if (!state.aiSelectionMode && state.aiSelection == null) return;
    _applyState(state.copyWith(aiSelectionMode: false, aiSelection: null));
  }

  void onAiSelectionChanged(PdfAiSelection? selection) {
    _applyState(
      state.copyWith(
        aiSelection: selection,
        aiPanelState: selection == null
            ? state.aiPanelState.copyWith(
                actionId: null,
                actionLabel: null,
                actionSelectionText: null,
                actionSelectionImage: null,
                result: null,
                reasoning: null,
                followUpSuggestions: const <String>[],
                errorMessage: null,
                loading: false,
              )
            : state.aiPanelState.copyWith(
                actionId: null,
                actionLabel: null,
                actionSelectionText: null,
                actionSelectionImage: null,
                followUpSuggestions: const <String>[],
                errorMessage: null,
              ),
      ),
    );
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

  /// 新建 AI 会话：清空对话历史，递增会话 ID（触发侧栏消息清空）。
  void startNewAiSession() {
    // 先使进行中的旧请求失效，防止其流式回调与终态写入新会话。
    _aiActionId++;
    _aiAgentSession.clear();
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

  Future<void> runAiAction(AiToolAction action) async {
    final PdfAiSelection? selection = state.aiSelection;
    if (selection == null) {
      return;
    }

    final int currentActionId = ++_aiActionId;
    _applyState(
      state.copyWith(
        aiSidebarVisible: true,
        aiPanelState: state.aiPanelState.copyWith(
          result: null,
          reasoning: null,
          followUpSuggestions: const <String>[],
          errorMessage: null,
        ),
      ),
    );

    final String apiKey = state.aiPanelState.apiKey;
    if (apiKey.trim().isEmpty) {
      _applyState(
        state.copyWith(
          aiSidebarVisible: true,
          aiPanelState: state.aiPanelState.copyWith(
            loading: false,
            reasoning: null,
            followUpSuggestions: const <String>[],
            errorMessage: '请先填写 DeepSeek API Key。',
          ),
        ),
      );
      return;
    }

    // 预提取选区截图与文本：提取完成后再一次性写入 loading + actionId +
    // 选区信息，确保界面上先出现用户气泡（含截图/文本），再出现模型侧
    // loading，随后流式输出 —— 避免 loading 占位先于用户消息入列。
    final Uint8List? imageBytes = await _pdfAiContextService
        .extractSelectionImageBytes(selection);
    final String selectionText = await _pdfAiContextService
        .resolveSelectionText(selection, imageBytes: imageBytes);
    if (!_isCurrentAiAction(currentActionId)) {
      return;
    }
    _applyState(
      state.copyWith(
        aiPanelState: state.aiPanelState.copyWith(
          loading: true,
          actionLabel: action.label,
          actionId: currentActionId,
          actionSelectionText: selectionText.trim().isEmpty
              ? null
              : selectionText,
          actionSelectionImage: imageBytes,
          reasoning: null,
          followUpSuggestions: const <String>[],
        ),
      ),
    );

    final AiModelConfig? config = AiModelRegistry.instance.configFor(
      DeepSeekService.model,
    );
    if (config != null &&
        config.supportsVision &&
        imageBytes != null &&
        imageBytes.isNotEmpty) {
      return _runVisionAction(
        action: action,
        selection: selection,
        apiKey: apiKey,
        currentActionId: currentActionId,
        imageBytes: imageBytes,
        selectionText: selectionText,
      );
    }
    return _runTextAction(
      action: action,
      selection: selection,
      apiKey: apiKey,
      currentActionId: currentActionId,
      extractedText: selectionText,
    );
  }

  /// 视觉模式只在服务端明确拒绝图片/多模态输入时回退纯文本；
  /// 认证、限流和网络错误直接展示，避免同一动作重复请求。
  Future<void> _runVisionAction({
    required AiToolAction action,
    required PdfAiSelection selection,
    required String apiKey,
    required int currentActionId,
    required Uint8List imageBytes,
    required String selectionText,
  }) async {
    try {
      final AiStreamResult result = await _aiAgentSession.runToolAction(
        action: action,
        apiKey: apiKey,
        selectionText: '',
        imageBytes: imageBytes,
        onPreview: (String text, String reasoning) {
          if (!_isCurrentAiAction(currentActionId)) return;
          _applyAiResponsePreview(text, reasoning: reasoning);
        },
      );
      if (!_isCurrentAiAction(currentActionId)) return;
      _applyAiResponseState(result);
    } on DeepSeekException catch (error) {
      if (!_isCurrentAiAction(currentActionId)) return;
      if (error.canFallbackToText && selectionText.trim().isNotEmpty) {
        return _runTextAction(
          action: action,
          selection: selection,
          apiKey: apiKey,
          currentActionId: currentActionId,
          extractedText: selectionText,
        );
      }
      _applyAiErrorState(error.message);
    } catch (error) {
      if (!_isCurrentAiAction(currentActionId)) return;
      _applyAiErrorState('请求失败：$error');
    }
  }

  Future<void> _runTextAction({
    required AiToolAction action,
    required PdfAiSelection selection,
    required String apiKey,
    required int currentActionId,
    required String extractedText,
  }) async {
    if (extractedText.trim().isEmpty) {
      _applyState(
        state.copyWith(
          aiSidebarVisible: true,
          aiPanelState: state.aiPanelState.copyWith(
            loading: false,
            actionLabel: action.label,
            actionId: currentActionId,
            result: null,
            reasoning: null,
            followUpSuggestions: const <String>[],
            errorMessage: '当前框选区域没有识别到可用文本。',
          ),
        ),
      );
      return;
    }

    final String? pageContext = await _pdfAiContextService.extractPageContext(
      selection,
    );
    if (!_isCurrentAiAction(currentActionId)) {
      return;
    }

    _applyState(
      state.copyWith(
        aiSidebarVisible: true,
        aiSelection: selection.copyWith(extractedText: extractedText),
        aiPanelState: state.aiPanelState.copyWith(
          loading: true,
          actionLabel: action.label,
          actionId: currentActionId,
          result: null,
          reasoning: null,
          followUpSuggestions: const <String>[],
          errorMessage: null,
        ),
      ),
    );

    try {
      final AiStreamResult result = await _aiAgentSession.runToolAction(
        action: action,
        apiKey: apiKey,
        selectionText: extractedText,
        pageContext: pageContext,
        onPreview: (String text, String reasoning) {
          if (!_isCurrentAiAction(currentActionId)) return;
          _applyAiResponsePreview(text, reasoning: reasoning);
        },
      );
      if (!_isCurrentAiAction(currentActionId)) return;
      _applyAiResponseState(result);
    } on DeepSeekException catch (error) {
      if (!_isCurrentAiAction(currentActionId)) return;
      _applyAiErrorState(error.message);
    } catch (error) {
      if (!_isCurrentAiAction(currentActionId)) return;
      _applyAiErrorState('请求失败：$error');
    }
  }

  Future<void> sendAiChat(AiChatInput input) async {
    if (input.isEmpty) {
      return;
    }
    final String apiKey = state.aiPanelState.apiKey;
    if (apiKey.trim().isEmpty) {
      _applyState(
        state.copyWith(
          aiSidebarVisible: true,
          aiPanelState: state.aiPanelState.copyWith(
            errorMessage: '请先填写 DeepSeek API Key。',
            followUpSuggestions: const <String>[],
          ),
        ),
      );
      return;
    }
    final String trimmedMessage = input.text.trim();
    final AiImageAttachment? image = input.image;
    final String historyMessage = trimmedMessage.isEmpty && image != null
        ? '请分析这张图片。'
        : trimmedMessage;
    final AiChatHistoryMessage userHistoryMessage = AiChatHistoryMessage.user(
      content: historyMessage,
      image: image,
    );
    final int currentActionId = ++_aiActionId;

    _applyState(
      state.copyWith(
        aiSidebarVisible: true,
        aiPanelState: state.aiPanelState.copyWith(
          loading: true,
          result: null,
          reasoning: null,
          followUpSuggestions: const <String>[],
          errorMessage: null,
        ),
      ),
    );

    try {
      final PdfAiContext? documentContext = await _pdfAiContextService
          .buildDocumentContext(
            filePath: state.filePath,
            fileName: state.fileName,
            currentPage: state.currentPage,
            outline: state.outline,
            message: trimmedMessage,
          );
      if (!_isCurrentAiAction(currentActionId)) {
        return;
      }
      final AiStreamResult result = await _aiAgentSession.sendChat(
        apiKey: apiKey,
        userMessage: userHistoryMessage,
        documentContext: documentContext,
        onPreview: (String text, String reasoning) {
          if (!_isCurrentAiAction(currentActionId)) return;
          _applyAiResponsePreview(text, reasoning: reasoning);
        },
      );
      if (!_isCurrentAiAction(currentActionId)) return;
      _applyAiResponseState(result);
    } on DeepSeekException catch (error) {
      if (!_isCurrentAiAction(currentActionId)) return;
      _applyAiErrorState(error.message);
    } catch (error) {
      if (!_isCurrentAiAction(currentActionId)) return;
      _applyAiErrorState('请求失败：$error');
    }
  }

  /// 流式完成后写入终态：正文、推理过程与追问建议。
  void _applyAiResponseState(AiStreamResult result) {
    _applyState(
      state.copyWith(
        aiPanelState: state.aiPanelState.copyWith(
          loading: false,
          result: result.content,
          reasoning: _nullableText(result.reasoning),
          followUpSuggestions: result.followUpSuggestions,
          errorMessage: null,
        ),
      ),
    );
  }

  void _applyAiErrorState(String message) {
    _applyState(
      state.copyWith(
        aiPanelState: state.aiPanelState.copyWith(
          loading: false,
          result: null,
          reasoning: null,
          followUpSuggestions: const <String>[],
          errorMessage: message,
        ),
      ),
    );
  }

  void _applyAiResponsePreview(String rawResponse, {String? reasoning}) {
    final AiResponse response = AiResponseParser.parse(rawResponse);
    _applyState(
      state.copyWith(
        aiPanelState: state.aiPanelState.copyWith(
          result: response.content,
          reasoning: _nullableText(reasoning),
          followUpSuggestions: response.followUpSuggestions,
        ),
      ),
    );
  }

  String? _nullableText(String? value) {
    final String text = value?.trim() ?? '';
    return text.isEmpty ? null : value;
  }
}
