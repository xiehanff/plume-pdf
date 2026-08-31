import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../routes/app_pages.dart';
import '../../../theme/app_colors.dart';
import '../controllers/home_controller.dart';
import '../models/pdf_reader_state.dart';
import 'widgets/ai_selectable_pdf_viewer.dart';
import 'widgets/error_reader_view.dart';
import 'widgets/mobile_reader_floating_toolbar.dart';
import 'widgets/recent_files_grid.dart';

/// iOS / Android 阅读器主界面。
///
/// 移动端以 PDF 阅读区域为主，不保留固定底栏。工具入口以右侧悬浮胶囊呈现：
/// - 点击 PDF 阅读区域显示；
/// - 开始上下滑动时隐藏；
/// - 大纲与 AI 仍通过独立路由展示；
/// - 页码、单双页和缩放按钮不进入悬浮栏；
/// - 适宽保留，用于手势缩放后恢复最佳阅读宽度。
class MobileHomeView extends StatefulWidget {
  const MobileHomeView({super.key});

  @override
  State<MobileHomeView> createState() => _MobileHomeViewState();
}

class _MobileHomeViewState extends State<MobileHomeView> {
  static const double _tapSlop = 6;

  late final HomeController _controller = Get.find<HomeController>();

  bool _toolbarVisible = false;
  int? _trackedPointer;
  Offset? _pointerDownPosition;
  bool _pointerMoved = false;

  void _showToolbar() {
    if (_toolbarVisible) {
      return;
    }
    setState(() {
      _toolbarVisible = true;
    });
  }

  void _hideToolbar() {
    if (!_toolbarVisible) {
      return;
    }
    setState(() {
      _toolbarVisible = false;
    });
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (_trackedPointer != null) {
      _pointerMoved = true;
      _hideToolbar();
      return;
    }
    _trackedPointer = event.pointer;
    _pointerDownPosition = event.position;
    _pointerMoved = false;
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (event.pointer != _trackedPointer) {
      return;
    }
    final Offset? start = _pointerDownPosition;
    if (start == null) {
      return;
    }
    final Offset delta = event.position - start;
    if (delta.distance >= _tapSlop) {
      _pointerMoved = true;
    }
    if (delta.dy.abs() >= _tapSlop) {
      _hideToolbar();
    }
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (event.pointer != _trackedPointer) {
      return;
    }
    if (!_pointerMoved) {
      _showToolbar();
    }
    _resetPointerTracking();
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    if (event.pointer == _trackedPointer) {
      _resetPointerTracking();
    }
  }

  void _resetPointerTracking() {
    _trackedPointer = null;
    _pointerDownPosition = null;
    _pointerMoved = false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: SafeArea(
        child: GetBuilder<HomeController>(
          id: HomeController.viewId,
          builder: (HomeController controller) {
            final PdfReaderState state = controller.state;
            if (!state.hasDocument && _toolbarVisible) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  _hideToolbar();
                }
              });
            }
            return ColoredBox(
              color: AppColors.surfaceBg,
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  // 移动端 PDF 直接使用 SafeArea 内完整宽度；悬浮工具栏覆盖在上方，
                  // 不参与 PDF 布局，也不为桌面滚动条预留宽度。
                  controller.updateRenderAreaWidth(
                    constraints.maxWidth,
                    reserveScrollbarInset: false,
                  );
                  return Stack(
                    children: <Widget>[
                      Positioned.fill(child: _buildBody(state)),
                      if (state.hasDocument)
                        Positioned(
                          right: MobileReaderFloatingToolbar.horizontalInset,
                          top: 0,
                          bottom: 0,
                          child: Center(
                            child: IgnorePointer(
                              ignoring: !_toolbarVisible,
                              child: AnimatedScale(
                                duration: const Duration(milliseconds: 150),
                                scale: _toolbarVisible ? 1 : 0.92,
                                curve: Curves.easeOutCubic,
                                child: AnimatedOpacity(
                                  duration: const Duration(milliseconds: 140),
                                  opacity: _toolbarVisible ? 1 : 0,
                                  curve: Curves.easeOut,
                                  child: MobileReaderFloatingToolbar(
                                    controller: controller,
                                    state: state,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
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
        onRetry: _controller.reopenFromError,
      );
    }
    if (!state.hasDocument) {
      return RecentFilesGrid(
        files: state.recentFiles,
        unavailableFilePaths: state.unavailableRecentFilePaths,
        onOpenFile: _controller.handleOpenFile,
        onOpenWifiTransfer: () => Get.toNamed<void>(Routes.wifiTransfer),
        onRecentFileTap: _controller.handleOpenRecentFile,
        onDeleteRecentFile: _controller.deleteRecentFile,
        onRecoverRecentFile: _controller.recoverRecentFile,
      );
    }
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _handlePointerDown,
      onPointerMove: _handlePointerMove,
      onPointerUp: _handlePointerUp,
      onPointerCancel: _handlePointerCancel,
      child: AiSelectablePdfViewer(
        filePath: state.filePath!,
        controller: _controller.pdfViewerController,
        initialPage: state.initialPage,
        spreadMode: false,
        lockHorizontalPan: _controller.shouldLockHorizontalPan,
        backgroundTheme: state.backgroundTheme,
        aiSelectionEnabled: state.aiSelectionMode,
        pageMargin: 0,
        showScrollThumb: false,
        onPageChanged: _controller.onPageChanged,
        onDocumentChanged: _controller.onDocumentChanged,
        onViewerReady: _controller.onViewerReady,
        onLoadError: _controller.onLoadError,
        onSelectionChanged: _controller.onAiSelectionChanged,
        onActionSelected: _controller.runAiAction,
      ),
    );
  }
}
