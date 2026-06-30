import '../../../theme/app_colors.dart';
import 'pdf_outline_entry.dart';
import 'pdf_ai_panel_state.dart';
import 'pdf_ai_selection.dart';
import 'pdf_recent_file.dart';

class PdfReaderState {
  const PdfReaderState({
    this.filePath,
    this.fileName,
    this.loading = false,
    this.errorMessage,
    this.currentPage = 1,
    this.pageCount = 0,
    this.zoom = 1,
    this.sidebarVisible = true,
    this.aiSidebarVisible = false,
    this.spreadMode = false,
    this.fitWidthActive = false,
    this.selectedOutlineId,
    this.initialPage = 1,
    this.outline = const <PdfOutlineEntry>[],
    this.recentFiles = const <PdfRecentFile>[],
    this.aiSelectionMode = false,
    this.aiSelection,
    this.aiPanelState = const PdfAiPanelState(),
    this.backgroundTheme = PdfBackgroundTheme.normal,
    this.draggingLocalFile = false,
    this.unavailableRecentFilePaths = const <String>{},
  });

  final String? filePath;
  final String? fileName;
  final bool loading;
  final String? errorMessage;
  final int currentPage;
  final int pageCount;
  final double zoom;
  final bool sidebarVisible;
  final bool aiSidebarVisible;
  final bool spreadMode;
  final bool fitWidthActive;
  final String? selectedOutlineId;
  final int initialPage;
  final List<PdfOutlineEntry> outline;
  final List<PdfRecentFile> recentFiles;
  final bool aiSelectionMode;
  final PdfAiSelection? aiSelection;
  final PdfAiPanelState aiPanelState;
  final PdfBackgroundTheme backgroundTheme;
  final bool draggingLocalFile;
  final Set<String> unavailableRecentFilePaths;

  bool get hasDocument => filePath != null && filePath!.isNotEmpty;

  PdfReaderState copyWith({
    Object? filePath = _sentinel,
    Object? fileName = _sentinel,
    bool? loading,
    Object? errorMessage = _sentinel,
    int? currentPage,
    int? pageCount,
    double? zoom,
    bool? sidebarVisible,
    bool? aiSidebarVisible,
    bool? spreadMode,
    bool? fitWidthActive,
    Object? selectedOutlineId = _sentinel,
    int? initialPage,
    List<PdfOutlineEntry>? outline,
    List<PdfRecentFile>? recentFiles,
    bool? aiSelectionMode,
    Object? aiSelection = _sentinel,
    PdfAiPanelState? aiPanelState,
    PdfBackgroundTheme? backgroundTheme,
    bool? draggingLocalFile,
    Set<String>? unavailableRecentFilePaths,
  }) {
    return PdfReaderState(
      filePath:
          identical(filePath, _sentinel) ? this.filePath : filePath as String?,
      fileName:
          identical(fileName, _sentinel) ? this.fileName : fileName as String?,
      loading: loading ?? this.loading,
      errorMessage: identical(errorMessage, _sentinel)
          ? this.errorMessage
          : errorMessage as String?,
      currentPage: currentPage ?? this.currentPage,
      pageCount: pageCount ?? this.pageCount,
      zoom: zoom ?? this.zoom,
      sidebarVisible: sidebarVisible ?? this.sidebarVisible,
      aiSidebarVisible: aiSidebarVisible ?? this.aiSidebarVisible,
      spreadMode: spreadMode ?? this.spreadMode,
      fitWidthActive: fitWidthActive ?? this.fitWidthActive,
      selectedOutlineId: identical(selectedOutlineId, _sentinel)
          ? this.selectedOutlineId
          : selectedOutlineId as String?,
      initialPage: initialPage ?? this.initialPage,
      outline: outline ?? this.outline,
      recentFiles: recentFiles ?? this.recentFiles,
      aiSelectionMode: aiSelectionMode ?? this.aiSelectionMode,
      aiSelection: identical(aiSelection, _sentinel)
          ? this.aiSelection
          : aiSelection as PdfAiSelection?,
      aiPanelState: aiPanelState ?? this.aiPanelState,
      backgroundTheme: backgroundTheme ?? this.backgroundTheme,
      draggingLocalFile: draggingLocalFile ?? this.draggingLocalFile,
      unavailableRecentFilePaths:
          unavailableRecentFilePaths ?? this.unavailableRecentFilePaths,
    );
  }
}

const Object _sentinel = Object();
