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
  // 历史与流式请求由会话层持有；PDF 提取依赖 viewerController，
  // 因此在字段初始化时绑定。
  late final PdfAiContextService _pdfAiContextService = PdfAiContextService(
    viewerController: pdfViewerController,
    ocrService: _macosOcrService,
  );
  int _aiSessionId = 0;
  int _aiActionId = 0;
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
    pdfViewerController.removeListener(_handleViewerChanged);
    pageTextController.dispose();
    if (Get.isRegistered<AiSidebarController>(tag: AiSidebarController.tag)) {
      Get.delete<AiSidebarController>(tag: AiSidebarController.tag);
    }
    super.onClose();
  }

  void onDocumentChanged(PdfDocument? document) {
    if (document == null) {
      return;
    }
    _applyState(
      state.copyWith(pageCount: document.pages.length, errorMessage: null),
    );
    unawaited(_loadOutline(document));
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

  void onPageChanged(int? pageNumber) {
    final int safePage = pageNumber ?? 1;
    _applyState(
      state.copyWith(
        currentPage: safePage,
        selectedOutlineId: _selectedOutlineIdForPage(safePage),
      ),
    );
    _setPageText('$safePage');
    _scheduleProgressSave();
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
    state = nextState;
    _syncAiSidebarController();
    update(<Object>[viewId]);
  }

  /// 唯一的侧栏状态同步入口：控制器已注册则无条件同步最新状态；
  /// 未注册时仅在侧栏需要展示（桌面可见或移动端 AI 路由 ensure 后）
  /// 才首次创建。流式期间每个状态变更只经由本方法同步一次，
  /// 视图层（MobileAiView）不再各自 post-frame 重复同步。
  void _syncAiSidebarController() {
    if (Get.isRegistered<AiSidebarController>(tag: AiSidebarController.tag)) {
      Get.find<AiSidebarController>(
        tag: AiSidebarController.tag,
      ).updateExternalState(
        state: state.aiPanelState,
        onApiKeyChanged: updateAiApiKey,
        onSaveApiKey: saveAiApiKey,
        onSendChat: sendAiChat,
        onNewSession: startNewAiSession,
        documentPath: state.filePath,
        leftSidebarWidth: state.sidebarVisible ? 260 : 0,
      );
      return;
    }
    if (state.aiSidebarVisible) {
      Get.put(
        AiSidebarController(
          state: state.aiPanelState,
          onApiKeyChanged: updateAiApiKey,
          onSaveApiKey: saveAiApiKey,
          onSendChat: sendAiChat,
          onNewSession: startNewAiSession,
          documentPath: state.filePath,
          leftSidebarWidth: state.sidebarVisible ? 260 : 0,
        ),
        tag: AiSidebarController.tag,
      );
    }
  }

  void _setPageText(String text) {
    pageTextController.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
