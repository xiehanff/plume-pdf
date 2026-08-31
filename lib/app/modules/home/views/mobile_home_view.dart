import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../routes/app_pages.dart';
import '../controllers/home_controller.dart';
import '../models/pdf_reader_state.dart';
import '../../../theme/app_colors.dart';
import 'widgets/ai_selectable_pdf_viewer.dart';
import 'widgets/error_reader_view.dart';
import 'widgets/mobile_reader_bottom_bar.dart';
import 'widgets/recent_files_grid.dart';

/// iOS / Android 阅读器主界面。
///
/// 与桌面端共用 [HomeController] 和 PDF/AI 业务状态，只替换页面骨架：
/// - 顶部只保留系统安全区，不显示桌面标题栏；
/// - PDF/最近文件区域占据主体；
/// - 底部固定移动端命令栏，并由 SafeArea 让出 Home Indicator / 导航栏；
/// - 目录与 AI 通过独立路由展示，不再占用 PDF 横向空间。
class MobileHomeView extends GetView<HomeController> {
  const MobileHomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: SafeArea(
        bottom: false,
        child: GetBuilder<HomeController>(
          id: HomeController.viewId,
          builder: (HomeController controller) {
            final PdfReaderState state = controller.state;
            return ColoredBox(
              color: AppColors.surfaceBg,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    controller.updateRenderAreaWidth(constraints.maxWidth);
                    return Stack(
                      children: <Widget>[
                        Positioned.fill(child: _buildBody(state)),
                        if (state.loading)
                          const Positioned.fill(
                            child: ColoredBox(
                              color: AppColors.loadingOverlay,
                              child: Center(
                                child: CircularProgressIndicator(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: GetBuilder<HomeController>(
          id: HomeController.viewId,
          builder: (HomeController controller) {
            return MobileReaderBottomBar(
              controller: controller,
              state: controller.state,
            );
          },
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
        onOpenWifiTransfer: () => Get.toNamed<void>(Routes.wifiTransfer),
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
