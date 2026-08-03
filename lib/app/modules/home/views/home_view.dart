import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';

import 'package:get/get.dart';

import '../controllers/home_controller.dart';
import '../models/pdf_reader_state.dart';
import '../../../theme/app_colors.dart';
import 'widgets/ai_sidebar.dart';
import 'widgets/app_title_bar.dart';
import 'widgets/error_reader_view.dart';
import 'widgets/ai_selectable_pdf_viewer.dart';
import 'widgets/page_status_bar.dart';
import 'widgets/reader_sidebar.dart';
import 'widgets/reader_shortcuts.dart';
import 'widgets/reader_toolbar.dart';
import 'widgets/recent_files_grid.dart';

class HomeView extends GetView<HomeController> {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return ReaderShortcuts(
      onOpenFile: controller.handleOpenFile,
      onPreviousPage: controller.goToPreviousPage,
      onNextPage: controller.goToNextPage,
      onZoomIn: controller.zoomIn,
      onZoomOut: controller.zoomOut,
      onActualSize: controller.actualSize,
      onToggleSidebar: controller.toggleSidebar,
      onEscape: controller.exitAiSelectionMode,
      child: DropTarget(
        onDragEntered: (_) => controller.setDraggingLocalFile(true),
        onDragExited: (_) => controller.setDraggingLocalFile(false),
        onDragDone: (DropDoneDetails detail) {
          controller.handleDroppedFiles(
            detail.files.map((file) => file.path).toList(),
          );
        },
        child: Scaffold(
          backgroundColor: AppColors.scaffoldBg,
          body: Column(
            children: <Widget>[
              AppTitleBar(
                child: GetBuilder<HomeController>(
                  id: HomeController.viewId,
                  builder: (HomeController controller) {
                    final PdfReaderState state = controller.state;
                    return ReaderToolbar(
                      fileName: state.fileName,
                      hasDocument: state.hasDocument && state.pageCount > 0,
                      pageController: controller.pageTextController,
                      currentPage: state.currentPage,
                      pageCount: state.pageCount,
                      zoomLabel: '${(state.zoom * 100).round()}%',
                      sidebarVisible: state.sidebarVisible,
                      spreadMode: state.spreadMode,
                      aiSelectionMode: state.aiSelectionMode,
                      aiSidebarVisible: state.aiSidebarVisible,
                      onOpenFile: controller.handleOpenFile,
                      onPreviousPage: controller.goToPreviousPage,
                      onNextPage: controller.goToNextPage,
                      onPageSubmitted: controller.jumpToPage,
                      onZoomOut: controller.zoomOut,
                      onZoomIn: controller.zoomIn,
                      onFitWidth: controller.fitWidth,
                      onActualSize: controller.actualSize,
                      onToggleSidebar: controller.toggleSidebar,
                      onToggleSpreadMode: controller.toggleSpreadMode,
                      onToggleAiSelectionMode: controller.toggleAiSelectionMode,
                      onToggleAiSidebar: controller.toggleAiSidebar,
                      onShowRecentFiles: controller.showRecentFiles,
                      onSetBackgroundTheme: controller.setBackgroundTheme,
                      backgroundTheme: state.backgroundTheme,
                    );
                  },
                ),
              ),
              Expanded(
                child: GetBuilder<HomeController>(
                  id: HomeController.viewId,
                  builder: (HomeController controller) {
                    final PdfReaderState state = controller.state;
                    return Column(
                      children: <Widget>[
                        Expanded(
                          child: Stack(
                            children: <Widget>[
                              Row(
                                children: <Widget>[
                                  if (state.hasDocument && state.sidebarVisible)
                                    ReaderSidebar(
                                      outline: state.outline,
                                      selectedOutlineId: state.selectedOutlineId,
                                      onOpenOutlinePage:
                                          controller.jumpToOutlinePage,
                                    ),
                                  Expanded(
                                    child: ColoredBox(
                                      color: AppColors.surfaceBg,
                                      child: Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: LayoutBuilder(
                                          builder: (_,
                                              BoxConstraints constraints) {
                                            controller.updateRenderAreaWidth(
                                                constraints.maxWidth);
                                            return Stack(
                                              children: <Widget>[
                                                Positioned.fill(
                                                    child:
                                                        _buildBody(state)),
                                                if (state.loading)
                                                  const Positioned.fill(
                                                    child: ColoredBox(
                                                      color: AppColors
                                                          .loadingOverlay,
                                                      child: Center(
                                                        child:
                                                            CircularProgressIndicator(
                                                          color: AppColors
                                                              .textSecondary,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (state.aiSidebarVisible)
                                    AiSidebar(
                                      state: state.aiPanelState,
                                      onApiKeyChanged:
                                          controller.updateAiApiKey,
                                      onSiliconFlowApiKeyChanged:
                                          controller.updateSiliconFlowApiKey,
                                      onSaveApiKey: controller.saveAiApiKey,
                                      onSaveSiliconFlowApiKey:
                                          controller.saveSiliconFlowApiKey,
                                      onProviderChanged:
                                          controller.updateSelectedProvider,
                                      onSendChat: controller.sendAiChat,
                                      documentPath: state.filePath,
                                      leftSidebarWidth:
                                          state.sidebarVisible ? 260 : 0,
                                    ),
                                ],
                              ),
                              if (state.draggingLocalFile)
                                Positioned.fill(
                                  child: IgnorePointer(
                                    child: ColoredBox(
                                      color: const Color(0x6632343E),
                                      child: Center(
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 28,
                                            vertical: 20,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.surfaceBg,
                                            borderRadius:
                                                BorderRadius.circular(18),
                                            border: Border.all(
                                              color: AppColors.borderFocused,
                                              width: 1.5,
                                            ),
                                          ),
                                          child: const Text(
                                            '松开以打开 PDF',
                                            style: TextStyle(
                                              color: AppColors.textPrimary,
                                              fontSize: 20,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        PageStatusBar(
                          fileName: state.fileName,
                          currentPage: state.currentPage,
                          pageCount: state.pageCount,
                          zoom: state.zoom,
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(PdfReaderState state) {
    if (state.errorMessage != null) {
      return ErrorReaderView(
        message: state.errorMessage!,
        onRetry: controller.reopenFromError,
      );
    }
    if (!state.hasDocument) {
      return RecentFilesGrid(
        files: state.recentFiles,
        unavailableFilePaths: state.unavailableRecentFilePaths,
        onOpenFile: controller.handleOpenFile,
        onRecentFileTap: controller.handleOpenRecentFile,
        onDeleteRecentFile: controller.deleteRecentFile,
        onRecoverRecentFile: controller.recoverRecentFile,
      );
    }
    return AiSelectablePdfViewer(
      filePath: state.filePath!,
      controller: controller.pdfViewerController,
      initialPage: state.initialPage,
      spreadMode: state.spreadMode,
      lockHorizontalPan: controller.shouldLockHorizontalPan,
      backgroundTheme: state.backgroundTheme,
      aiSelectionEnabled: state.aiSelectionMode,
      onPageChanged: controller.onPageChanged,
      onDocumentChanged: controller.onDocumentChanged,
      onViewerReady: controller.onViewerReady,
      onLoadError: controller.onLoadError,
      onSelectionChanged: controller.onAiSelectionChanged,
      onActionSelected: controller.runAiAction,
    );
  }
}
