import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as path;
import 'package:pdfrx/pdfrx.dart';

import '../models/ai_chat_history_message.dart';
import '../models/pdf_outline_entry.dart';
import '../models/ai_chat_input.dart';
import '../models/pdf_ai_panel_state.dart';
import '../models/pdf_ai_context.dart';
import 'ai_sidebar_controller.dart';
import '../models/pdf_ai_selection.dart';
import '../models/pdf_reader_state.dart';
import '../models/pdf_recent_file.dart';
import '../services/ai_agent_session.dart';
import '../services/deepseek_service.dart';
import '../services/deepseek_settings_store.dart';
import '../services/macos_file_open_service.dart';
import '../services/macos_ocr_service.dart';
import '../services/pdf_ai_context_service.dart';
import '../services/pdf_file_picker.dart';
import '../services/pdf_outline_mapper.dart';
import '../services/pdf_cover_cache.dart';
import '../services/pdf_reader_store.dart';
import '../services/ai_model_config.dart';
import '../services/ai_response_parser.dart';
import '../../../services/app_launch_args.dart';
import '../../../theme/app_colors.dart';

part 'home_controller_navigation.dart';
part 'home_controller_ai_session.dart';
part 'home_controller_file_manager.dart';

class HomeController extends GetxController {
  static const String viewId = 'reader_view';
  static const double _zoomStepFactor = 1.08;
  static const double _kScrollbarWidth = 12; // 8px thumb + 4px margin

  final PdfViewerController pdfViewerController = PdfViewerController();
  final TextEditingController pageTextController = TextEditingController(
    text: '1',
  );

  final PdfReaderStore _store = PdfReaderStore();
  final PdfFilePicker _filePicker = PdfFilePicker();
  final PdfOutlineMapper _outlineMapper = const PdfOutlineMapper();
  final DeepSeekSettingsStore _deepSeekSettingsStore = DeepSeekSettingsStore();
  final MacosFileOpenService _macosFileOpenService = MacosFileOpenService();
  final MacosOcrService _macosOcrService = MacosOcrService();
  final AiAgentSession _aiAgentSession = AiAgentSession();
  late final PdfAiContextService _pdfAiContextService = PdfAiContextService(
    viewerController: pdfViewerController,
    ocrService: _macosOcrService,
  );
  int _aiSessionId = 0;
  int _aiActionId = 0;
  int _outlineLoadId = 0;
  String? _pinnedOutlineId;
  int? _pinnedOutlinePage;
  int? _pendingOutlineTargetPage;
  String? _pendingStartupFilePath;

  PdfReaderState state = const PdfReaderState();
  Timer? _saveDebounce;
  double _renderAreaWidth = 0;
  bool _reserveFitWidthScrollbarInset = true;
  int _recentFilesCheckId = 0;

  @override
  void onInit() {
    super.onInit();
    _registerAiSidebarController();
    _pendingStartupFilePath = _resolveStartupPdfPath();
    unawaited(
      _loadRecentFiles().then((_) => _openPendingStartupFileIfNeeded()),
    );
    _loadAiApiKey();
    _loadBackgroundTheme();
    unawaited(
      AiModelRegistry.initialize().then((_) {
        _applyState(state);
      }),
    );
    unawaited(_macosFileOpenService.bindOpenHandler(_handleOpenedFiles));
    pdfViewerController.addListener(_handleViewerChanged);
  }

  @override
  void onClose() {
    _saveDebounce?.cancel();
    _aiAgentSession.stopActiveStream();
    pdfViewerController.removeListener(_handleViewerChanged);
    pageTextController.dispose();
    if (Get.isRegistered<AiSidebarController>(tag: AiSidebarController.tag)) {
      Get.delete<AiSidebarController>(tag: AiSidebarController.tag);
    }
    super.onClose();
  }

  void onDocumentChanged(String filePath, PdfDocument? document) {
    if (document == null || state.filePath != filePath) {
      return;
    }
    final int loadId = ++_outlineLoadId;
    _applyState(
      state.copyWith(pageCount: document.pages.length, errorMessage: null),
    );
    unawaited(
      _loadOutline(
        document,
        sourceFilePath: filePath,
        loadId: loadId,
      ),
    );
  }

  void onViewerReady(PdfDocument document, PdfViewerController controller) {
    _applyState(state.copyWith(loading: false, errorMessage: null));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      fitWidth();
    });
  }

  void onLoadError(Object error, StackTrace? stackTrace) {
    debugPrint('[plume_pdf] onLoadError: $error');
    _showError('打开失败：$error');
  }

  void toggleSidebar() {
    _applyState(state.copyWith(sidebarVisible: !state.sidebarVisible));
  }

  void toggleAiSidebar() {
    _applyState(state.copyWith(aiSidebarVisible: !state.aiSidebarVisible));
  }

  String? _resolveStartupPdfPath() {
    if (!Platform.isWindows) {
      return null;
    }
    final String? startupPdfPath = AppLaunchArgs.firstPdfPath();
    if (startupPdfPath != null) {
      return startupPdfPath;
    }
    for (final String argument in Platform.executableArguments) {
      if (!_isPdfFile(argument)) {
        continue;
      }
      final File file = File(argument);
      if (!file.existsSync()) {
        continue;
      }
      return argument;
    }
    return null;
  }

  Future<void> _openPendingStartupFileIfNeeded() async {
    final String? filePath = _pendingStartupFilePath;
    if (filePath == null || state.hasDocument) {
      return;
    }
    _pendingStartupFilePath = null;
    debugPrint('[plume_pdf] open file from Windows startup args: $filePath');
    await openFilePath(filePath);
  }

  PdfReaderState _buildLoadingState(String filePath, int initialPage) {
    return state.copyWith(
      filePath: filePath,
      fileName: path.basename(filePath),
      loading: true,
      errorMessage: null,
      currentPage: initialPage,
      pageCount: 0,
      initialPage: initialPage,
      selectedOutlineId: null,
      outline: const <PdfOutlineEntry>[],
      zoom: 1,
      fitWidthActive: false,
      aiSelection: null,
      aiPanelState: state.aiPanelState.copyWith(
        sessionId: _aiSessionId,
        loading: false,
        actionId: null,
        actionLabel: null,
        actionSelectionText: null,
        actionSelectionImage: null,
        result: null,
        followUpSuggestions: const <String>[],
        errorMessage: null,
      ),
    );
  }

  void _showError(String message) {
    _applyState(state.copyWith(loading: false, errorMessage: message));
  }

  void _applyState(PdfReaderState nextState) {
    final PdfReaderState previousState = state;
    state = nextState;
    if (_shouldSyncAiSidebarController(previousState, nextState)) {
      _syncAiSidebarController();
    }

    final bool aiPanelChanged =
        !identical(previousState.aiPanelState, nextState.aiPanelState);
    if (!aiPanelChanged || _readerViewStateChanged(previousState, nextState)) {
      update(<Object>[viewId]);
    }
  }

  bool _shouldSyncAiSidebarController(
    PdfReaderState previousState,
    PdfReaderState nextState,
  ) {
    return !identical(previousState.aiPanelState, nextState.aiPanelState) ||
        previousState.filePath != nextState.filePath ||
        previousState.sidebarVisible != nextState.sidebarVisible;
  }

  bool _readerViewStateChanged(
    PdfReaderState previousState,
    PdfReaderState nextState,
  ) {
    return previousState.filePath != nextState.filePath ||
        previousState.fileName != nextState.fileName ||
        previousState.loading != nextState.loading ||
        previousState.errorMessage != nextState.errorMessage ||
        previousState.currentPage != nextState.currentPage ||
        previousState.pageCount != nextState.pageCount ||
        previousState.zoom != nextState.zoom ||
        previousState.sidebarVisible != nextState.sidebarVisible ||
        previousState.aiSidebarVisible != nextState.aiSidebarVisible ||
        previousState.spreadMode != nextState.spreadMode ||
        previousState.fitWidthActive != nextState.fitWidthActive ||
        previousState.selectedOutlineId != nextState.selectedOutlineId ||
        previousState.initialPage != nextState.initialPage ||
        !identical(previousState.outline, nextState.outline) ||
        !identical(previousState.recentFiles, nextState.recentFiles) ||
        previousState.aiSelectionMode != nextState.aiSelectionMode ||
        !identical(previousState.aiSelection, nextState.aiSelection) ||
        previousState.backgroundTheme != nextState.backgroundTheme ||
        previousState.draggingLocalFile != nextState.draggingLocalFile ||
        !identical(
          previousState.unavailableRecentFilePaths,
          nextState.unavailableRecentFilePaths,
        );
  }

  void _registerAiSidebarController() {
    if (Get.isRegistered<AiSidebarController>(tag: AiSidebarController.tag)) {
      return;
    }
    Get.put<AiSidebarController>(
      AiSidebarController(
        state: state.aiPanelState,
        onApiKeyChanged: updateAiApiKey,
        onSaveApiKey: saveAiApiKey,
        onSendChat: sendAiChat,
        onStopChat: stopAiResponse,
        onNewSession: startNewAiSession,
        documentPath: state.filePath,
        leftSidebarWidth: state.sidebarVisible ? 260 : 0,
      ),
      tag: AiSidebarController.tag,
    );
  }

  void _syncAiSidebarController() {
    if (!Get.isRegistered<AiSidebarController>(tag: AiSidebarController.tag)) {
      return;
    }
    Get.find<AiSidebarController>(
      tag: AiSidebarController.tag,
    ).updateExternalState(
      state: state.aiPanelState,
      onApiKeyChanged: updateAiApiKey,
      onSaveApiKey: saveAiApiKey,
      onSendChat: sendAiChat,
      onStopChat: stopAiResponse,
      onNewSession: startNewAiSession,
      documentPath: state.filePath,
      leftSidebarWidth: state.sidebarVisible ? 260 : 0,
    );
  }

  void _setPageText(String text) {
    pageTextController.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
