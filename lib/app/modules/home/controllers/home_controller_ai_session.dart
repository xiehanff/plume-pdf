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
                result: null,
                errorMessage: null,
                loading: false,
              )
            : state.aiPanelState.copyWith(errorMessage: null),
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

  void updateSiliconFlowApiKey(String apiKey) {
    _applyState(
      state.copyWith(
        aiPanelState: state.aiPanelState.copyWith(siliconFlowApiKey: apiKey),
      ),
    );
  }

  void updateSelectedProvider(AiProvider provider) {
    _applyState(
      state.copyWith(
        aiPanelState: state.aiPanelState.copyWith(selectedProvider: provider),
      ),
    );
    unawaited(_deepSeekSettingsStore.saveSelectedProvider(provider.name));
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

  Future<void> saveSiliconFlowApiKey() async {
    await _siliconFlowSettingsStore.saveApiKey(state.aiPanelState.siliconFlowApiKey);
    _applyState(
      state.copyWith(
        aiPanelState: state.aiPanelState.copyWith(
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
          loading: true,
          actionLabel: action.label,
          actionId: currentActionId,
          result: null,
          errorMessage: null,
        ),
      ),
    );

    final bool useSiliconFlow = state.aiPanelState.selectedProvider == AiProvider.siliconFlow;
    final String apiKey = useSiliconFlow
        ? state.aiPanelState.siliconFlowApiKey
        : state.aiPanelState.apiKey;
    final String providerName = useSiliconFlow ? '硅基流动' : 'DeepSeek';

    if (apiKey.trim().isEmpty) {
      _applyState(
        state.copyWith(
          aiSidebarVisible: true,
          aiPanelState: state.aiPanelState.copyWith(
            loading: false,
            errorMessage: '请先填写$providerName API Key。',
          ),
        ),
      );
      return;
    }

    final String modelId = useSiliconFlow ? SiliconFlowService.model : DeepSeekService.model;
    final AiModelConfig? config = AiModelRegistry.instance.configFor(modelId);

    if (config != null && config.supportsVision) {
      return _runVisionAction(
        action: action,
        selection: selection,
        apiKey: apiKey,
        currentActionId: currentActionId,
      );
    }
    return _runTextAction(
      action: action,
      selection: selection,
      apiKey: apiKey,
      useSiliconFlow: useSiliconFlow,
      currentActionId: currentActionId,
    );
  }

  Future<void> _runVisionAction({
    required AiToolAction action,
    required PdfAiSelection selection,
    required String apiKey,
    required int currentActionId,
  }) async {
    final Uint8List? imageBytes = await _extractSelectionImageBytes(selection);
    if (imageBytes == null || imageBytes.isEmpty) {
      return _runTextAction(
        action: action,
        selection: selection,
        apiKey: apiKey,
        useSiliconFlow: true,
        currentActionId: currentActionId,
      );
    }

    try {
      final List<Map<String, String>> history = List<Map<String, String>>.from(_aiChatHistory);
      final String result = await _siliconFlowService.perform(
        action: action,
        apiKey: apiKey,
        selectionText: '',
        history: history,
        imageBytes: imageBytes,
      );
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
    } on SiliconFlowException catch (_) {
      return _runTextAction(
        action: action,
        selection: selection,
        apiKey: apiKey,
        useSiliconFlow: true,
        currentActionId: currentActionId,
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
    required bool useSiliconFlow,
    required int currentActionId,
  }) async {
    final String extractedText = await _resolveSelectionText(selection);
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
      final String userContent = pageContext != null && pageContext.trim().isNotEmpty
          ? '请${action.label}以下【框选内容】，页面全文仅作上下文参考：\n\n【框选内容】\n$extractedText\n\n【页面全文参考】\n$pageContext'
          : '请${action.label}以下内容：\n\n$extractedText';
      _aiChatHistory.add(<String, String>{'role': 'user', 'content': userContent});

      final String result;
      if (useSiliconFlow) {
        result = await _siliconFlowService.perform(
          action: action,
          apiKey: apiKey,
          selectionText: extractedText,
          pageContext: pageContext,
          history: List<Map<String, String>>.from(_aiChatHistory),
        );
      } else {
        result = await _deepSeekService.perform(
          action: action,
          apiKey: apiKey,
          selectionText: extractedText,
          pageContext: pageContext,
          history: List<Map<String, String>>.from(_aiChatHistory),
        );
      }

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
      _aiChatHistory.removeLast();
      _applyState(
        state.copyWith(
          aiPanelState: state.aiPanelState.copyWith(
            loading: false,
            result: null,
            errorMessage: error.message,
          ),
        ),
      );
    } on SiliconFlowException catch (error) {
      _aiChatHistory.removeLast();
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
      _aiChatHistory.removeLast();
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
    final bool useSiliconFlow = state.aiPanelState.selectedProvider == AiProvider.siliconFlow;
    final String apiKey = useSiliconFlow
        ? state.aiPanelState.siliconFlowApiKey
        : state.aiPanelState.apiKey;
    final String providerName = useSiliconFlow ? '硅基流动' : 'DeepSeek';

    if (apiKey.trim().isEmpty) {
      _applyState(
        state.copyWith(
          aiSidebarVisible: true,
          aiPanelState: state.aiPanelState.copyWith(
            errorMessage: '请先填写$providerName API Key。',
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

      final String result;
      if (useSiliconFlow) {
        result = await _siliconFlowService.chat(
          apiKey: apiKey,
          history: List<Map<String, String>>.from(_aiChatHistory),
        );
      } else {
        result = await _deepSeekService.chat(
          apiKey: apiKey,
          history: List<Map<String, String>>.from(_aiChatHistory),
        );
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
    } on SiliconFlowException catch (error) {
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

  Future<String> _resolveSelectionText(PdfAiSelection selection) async {
    final String directText = await _extractSelectionText(selection);
    if (directText.trim().isNotEmpty) {
      return directText;
    }

    final Uint8List? imageBytes = await _extractSelectionImageBytes(selection);
    if (imageBytes == null || imageBytes.isEmpty) {
      return '';
    }
    return _macosOcrService.recognizeText(imageBytes);
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
