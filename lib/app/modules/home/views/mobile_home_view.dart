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
/// - 翻页、缩放、适宽、单双页等触屏可直接完成的动作不进入悬浮栏。
class MobileHomeView extends StatefulWidget {
  const MobileHomeView({super.key});

  @override
  State<MobileHomeView> createState() => _MobileHomeViewState();
}

class _MobileHomeViewState extends State<MobileHomeView> {
  late final HomeController _controller = Get.find<HomeController>();

  bool _toolbarVisible = false;
  double? _pointerDownY;

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
    _pointerDownY = event.position.dy;
  }

  void _handlePointerMove(PointerMoveEvent event) {
    final double? pointerDownY = _pointerDownY;
    if (pointerDownY == null) {
      return;
    }
    if ((event.position.dy - pointerDownY).abs() >= 6) {
      _hideToolbar();
    }
  }

  void _resetPointerTracking([PointerEvent? _]) {
    _pointerDownY = null;
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
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    controller.updateRenderAreaWidth(constraints.maxWidth);
                    return Stack(
                      clipBehavior: Clip.none,
                      children: <Widget>[
                        Positioned.fill(child: _buildBody(state)),
                        if (state.hasDocument)
                          Positioned.fill(
                            child: _PdfInteractionLayer(
                              onTap: _showToolbar,
                              onPointerDown: _handlePointerDown,
                              onPointerMove: _handlePointerMove,
                              onPointerUp: _resetPointerTracking,
                              onPointerCancel: _resetPointerTracking,
                            ),
                          ),
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
    return AiSelectablePdfViewer(
      filePath: state.filePath!,
      controller: _controller.pdfViewerController,
      initialPage: state.initialPage,
      spreadMode: false,
      lockHorizontalPan: _controller.shouldLockHorizontalPan,
      backgroundTheme: state.backgroundTheme,
      aiSelectionEnabled: state.aiSelectionMode,
      onPageChanged: _controller.onPageChanged,
      onDocumentChanged: _controller.onDocumentChanged,
      onViewerReady: _controller.onViewerReady,
      onLoadError: _controller.onLoadError,
      onSelectionChanged: _controller.onAiSelectionChanged,
      onActionSelected: _controller.runAiAction,
    );
  }
}

/// 透明的原始指针监听层，不参与 Flutter gesture arena，因此不会抢占
/// pdfrx 的拖动、缩放与选择手势；仅用于判断“点击显示 / 纵向移动隐藏”。
class _PdfInteractionLayer extends StatelessWidget {
  const _PdfInteractionLayer({
    required this.onTap,
    required this.onPointerDown,
    required this.onPointerMove,
    required this.onPointerUp,
    required this.onPointerCancel,
  });

  final VoidCallback onTap;
  final PointerDownEventListener onPointerDown;
  final PointerMoveEventListener onPointerMove;
  final PointerUpEventListener onPointerUp;
  final PointerCancelEventListener onPointerCancel;

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: onPointerDown,
      onPointerMove: onPointerMove,
      onPointerUp: (PointerUpEvent event) {
        onPointerUp(event);
        onTap();
      },
      onPointerCancel: onPointerCancel,
      child: const SizedBox.expand(),
    );
  }
}
