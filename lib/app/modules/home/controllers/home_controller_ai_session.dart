part of 'home_controller.dart';

extension HomeControllerAiSession on HomeController {
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
    _applyState(
      state.copyWith(
        aiSelectionMode: false,
        aiSelection: null,
      ),
    );
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
                errorMessage: null,
                loading: false,
              )
            : state.aiPanelState.copyWith(
                actionId: null,
                actionLabel: null,
                actionSelectionText: null,
                actionSelectionImage: null,
                errorMessage: null,
              ),
      ),
    );
  }

  void updateAiApiKey(String apiKey) {
    _applyState(
      state.copyWith(
        aiPanelState: state.aiPanelState.copyWith(apiKey: apiKey),
      ),
    );
  }

  Future<void> saveAiApiKey() async {
    await _deepSeekSettingsStore.saveApiKey(state.aiPanelState.apiKey);
    _applyState(
      state.copyWith(
        aiPanelState: state.aiPanelState.copyWith(
          errorMessage: null,
        ),
      ),
    );
  }

  /// 新建 AI 会话：清空对话历史，递增会话 ID（触发侧栏消息清空）。
  void startNewAiSession() {
    _aiChatHistory.clear();
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
            errorMessage: '请先填写 DeepSeek API Key。',
          ),
        ),
      );
      return;
    }

    // 预提取选区截图与文本：提取完成后再一次性写入 loading + actionId +
    // 选区信息，确保界面上先出现用户气泡（含截图/文本），再出现模型侧
    // loading，随后流式输出 —— 避免 loading 占位先于用户消息入列。
    final Uint8List? imageBytes = await _extractSelectionImageBytes(selection);
    final String selectionText =
        await _resolveSelectionText(selection, imageBytes: imageBytes);
    _applyState(
      state.copyWith(
        aiPanelState: state.aiPanelState.copyWith(
          loading: true,
          actionLabel: action.label,
          actionId: currentActionId,
          actionSelectionText:
              selectionText.trim().isEmpty ? null : selectionText,
          actionSelectionImage: imageBytes,
        ),
      ),
    );

    final AiModelConfig? config =
        AiModelRegistry.instance.configFor(DeepSeekService.model);
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

  Future<void> _runVisionAction({
    required AiToolAction action,
    required PdfAiSelection selection,
    required String apiKey,
    required int currentActionId,
    required Uint8List imageBytes,
    required String selectionText,
  }) async {
    if (imageBytes.isEmpty) {
      return _runTextAction(
        action: action,
        selection: selection,
        apiKey: apiKey,
        currentActionId: currentActionId,
        extractedText: selectionText,
      );
    }

    try {
      final List<Map<String, String>> history = List<Map<String, String>>.from(_aiChatHistory);
      final StringBuffer buffer = StringBuffer();
      await for (final String chunk in _deepSeekService.performStream(
        action: action,
        apiKey: apiKey,
        selectionText: '',
        history: history,
        imageBytes: imageBytes,
      )) {
        buffer.write(chunk);
        _applyState(
          state.copyWith(
            aiPanelState: state.aiPanelState.copyWith(result: buffer.toString()),
          ),
        );
      }
      final String result = buffer.toString().trim();
      if (result.isEmpty) {
        throw const DeepSeekException('DeepSeek 没有返回可展示的内容。');
      }
      _aiChatHistory.add(<String, String>{
        'role': 'user',
        'content': AiPrompts.visionUserPrompt(action),
      });
      _aiChatHistory.add(<String, String>{
        'role': 'assistant',
        'content': result,
      });
      _applyState(
        state.copyWith(
          aiPanelState: state.aiPanelState.copyWith(
            loading: false,
            result: result,
            errorMessage: null,
          ),
        ),
      );
    } on DeepSeekException catch (_) {
      return _runTextAction(
        action: action,
        selection: selection,
        apiKey: apiKey,
        currentActionId: currentActionId,
        extractedText: selectionText,
      );
    } catch (error) {
      _applyState(
        state.copyWith(
          aiPanelState: state.aiPanelState.copyWith(
            loading: false,
            result: null,
            errorMessage: '请求失败：$error',
          ),
        ),
      );
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
            errorMessage: '当前框选区域没有识别到可用文本。',
          ),
        ),
      );
      return;
    }

    final String? pageContext = await _extractPageContext(selection);

    _applyState(
      state.copyWith(
        aiSidebarVisible: true,
        aiSelection: selection.copyWith(extractedText: extractedText),
        aiPanelState: state.aiPanelState.copyWith(
          loading: true,
          actionLabel: action.label,
          actionId: currentActionId,
          result: null,
          errorMessage: null,
        ),
      ),
    );

    try {
      // 注意：当前用户消息由 performStream 追加，这里只传既有历史
      // （不含本轮 user），成功后再写入会话历史，避免重复发送。
      final StringBuffer buffer = StringBuffer();
      await for (final String chunk in _deepSeekService.performStream(
        action: action,
        apiKey: apiKey,
        selectionText: extractedText,
        pageContext: pageContext,
        history: List<Map<String, String>>.from(_aiChatHistory),
      )) {
        buffer.write(chunk);
        _applyState(
          state.copyWith(
            aiPanelState: state.aiPanelState.copyWith(result: buffer.toString()),
          ),
        );
      }
      final String result = buffer.toString().trim();
      if (result.isEmpty) {
        throw const DeepSeekException('DeepSeek 没有返回可展示的内容。');
      }

      final String userContent = AiPrompts.userPrompt(
        action,
        extractedText,
        pageContext: pageContext,
      );
      _aiChatHistory.add(<String, String>{'role': 'user', 'content': userContent});
      _aiChatHistory.add(<String, String>{'role': 'assistant', 'content': result});
      _applyState(
        state.copyWith(
          aiPanelState: state.aiPanelState.copyWith(
            loading: false,
            result: result,
            errorMessage: null,
          ),
        ),
      );
    } on DeepSeekException catch (error) {
      _applyState(
        state.copyWith(
          aiPanelState: state.aiPanelState.copyWith(
            loading: false,
            result: null,
            errorMessage: error.message,
          ),
        ),
      );
    } catch (error) {
      _applyState(
        state.copyWith(
          aiPanelState: state.aiPanelState.copyWith(
            loading: false,
            result: null,
            errorMessage: '请求失败：$error',
          ),
        ),
      );
    }
  }

  Future<void> sendAiChat(String message) async {
    final String apiKey = state.aiPanelState.apiKey;
    if (apiKey.trim().isEmpty) {
      _applyState(
        state.copyWith(
          aiSidebarVisible: true,
          aiPanelState: state.aiPanelState.copyWith(
            errorMessage: '请先填写 DeepSeek API Key。',
          ),
        ),
      );
      return;
    }
    final String trimmedMessage = message.trim();
    if (trimmedMessage.isEmpty) {
      return;
    }

    _applyState(
      state.copyWith(
        aiSidebarVisible: true,
        aiPanelState: state.aiPanelState.copyWith(
          loading: true,
          errorMessage: null,
        ),
      ),
    );

    try {
      _aiChatHistory.add(<String, String>{
        'role': 'user',
        'content': trimmedMessage,
      });

      final StringBuffer buffer = StringBuffer();
      await for (final String chunk in _deepSeekService.chatStream(
        apiKey: apiKey,
        history: List<Map<String, String>>.from(_aiChatHistory),
      )) {
        buffer.write(chunk);
        _applyState(
          state.copyWith(
            aiPanelState: state.aiPanelState.copyWith(result: buffer.toString()),
          ),
        );
      }
      final String result = buffer.toString().trim();
      if (result.isEmpty) {
        throw const DeepSeekException('DeepSeek 没有返回可展示的内容。');
      }

      _aiChatHistory.add(<String, String>{
        'role': 'assistant',
        'content': result,
      });
      _applyState(
        state.copyWith(
          aiPanelState: state.aiPanelState.copyWith(
            loading: false,
            result: result,
            errorMessage: null,
          ),
        ),
      );
    } on DeepSeekException catch (error) {
      if (_aiChatHistory.isNotEmpty &&
          _aiChatHistory.last['role'] == 'user' &&
          _aiChatHistory.last['content'] == trimmedMessage) {
        _aiChatHistory.removeLast();
      }
      _applyState(
        state.copyWith(
          aiPanelState: state.aiPanelState.copyWith(
            loading: false,
            result: null,
            errorMessage: error.message,
          ),
        ),
      );
    } catch (error) {
      if (_aiChatHistory.isNotEmpty &&
          _aiChatHistory.last['role'] == 'user' &&
          _aiChatHistory.last['content'] == trimmedMessage) {
        _aiChatHistory.removeLast();
      }
      _applyState(
        state.copyWith(
          aiPanelState: state.aiPanelState.copyWith(
            loading: false,
            result: null,
            errorMessage: '请求失败：$error',
          ),
        ),
      );
    }
  }

  Future<String> _extractSelectionText(PdfAiSelection selection) async {
    return await pdfViewerController.useDocument<String>(
          (PdfDocument document) async {
            if (selection.pageNumber < 1 ||
                selection.pageNumber > document.pages.length) {
              return '';
            }
            final PdfPageText pageText =
                await document.pages[selection.pageNumber - 1].loadText();
            final Iterable<String> texts = pageText.fragments
                .where(
                  (PdfPageTextFragment fragment) =>
                      _intersects(selection.bounds, fragment.bounds),
                )
                .map((PdfPageTextFragment fragment) => fragment.text.trim())
                .where((String text) => text.isNotEmpty);
            return texts.join('\n');
          },
        ) ??
        '';
  }

  Future<String?> _extractPageContext(PdfAiSelection selection) async {
    return await pdfViewerController.useDocument<String?>(
          (PdfDocument document) async {
            if (selection.pageNumber < 1 ||
                selection.pageNumber > document.pages.length) {
              return null;
            }
            final PdfPageText pageText =
                await document.pages[selection.pageNumber - 1].loadText();
            final String fullText = pageText.fragments
                .map((PdfPageTextFragment f) => f.text.trim())
                .where((String t) => t.isNotEmpty)
                .join('\n');
            return fullText.trim().isEmpty ? null : fullText;
          },
        );
  }

  Future<String> _resolveSelectionText(
    PdfAiSelection selection, {
    Uint8List? imageBytes,
  }) async {
    final String directText = await _extractSelectionText(selection);
    if (directText.trim().isNotEmpty) {
      return directText;
    }

    final Uint8List? bytes =
        imageBytes ?? await _extractSelectionImageBytes(selection);
    if (bytes == null || bytes.isEmpty) {
      return '';
    }
    return _macosOcrService.recognizeText(bytes);
  }

  Future<Uint8List?> _extractSelectionImageBytes(PdfAiSelection selection) async {
    return pdfViewerController.useDocument<Uint8List?>(
      (PdfDocument document) async {
        if (selection.pageNumber < 1 ||
            selection.pageNumber > document.pages.length) {
          return null;
        }
        final PdfPage page = document.pages[selection.pageNumber - 1];
        const double scale = 3;
        final double fullWidth = page.width * scale;
        final double fullHeight = page.height * scale;
        final int maxX = math.max(0, fullWidth.ceil() - 1);
        final int maxY = math.max(0, fullHeight.ceil() - 1);
        final int x = (selection.bounds.left * scale).floor().clamp(
          0,
          maxX,
        );
        final int y = ((page.height - selection.bounds.top) * scale)
            .floor()
            .clamp(0, maxY);
        final int width = (selection.bounds.width * scale)
            .ceil()
            .clamp(1, fullWidth.ceil());
        final int height = (selection.bounds.height * scale)
            .ceil()
            .clamp(1, fullHeight.ceil());
        final int safeWidth = width.clamp(1, math.max(1, fullWidth.ceil() - x));
        final int safeHeight =
            height.clamp(1, math.max(1, fullHeight.ceil() - y));
        final PdfImage? rendered = await page.render(
          x: x,
          y: y,
          width: safeWidth,
          height: safeHeight,
          fullWidth: fullWidth,
          fullHeight: fullHeight,
        );
        if (rendered == null) {
          return null;
        }

        final ui.Image image = await rendered.createImage();
        rendered.dispose();
        final ByteData? data = await image.toByteData(
          format: ui.ImageByteFormat.png,
        );
        image.dispose();
        return data?.buffer.asUint8List();
      },
    );
  }

  bool _intersects(PdfRect a, PdfRect b) {
    return a.left < b.right &&
        a.right > b.left &&
        a.bottom < b.top &&
        a.top > b.bottom;
  }
}
