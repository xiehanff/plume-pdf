part of 'home_controller.dart';

extension HomeControllerNavigation on HomeController {
  Future<void> goToPreviousPage() async {
    if (!state.hasDocument || state.currentPage <= 1) {
      return;
    }
    await pdfViewerController.goToPage(pageNumber: state.currentPage - 1);
  }

  Future<void> goToNextPage() async {
    if (!state.hasDocument ||
        state.pageCount == 0 ||
        state.currentPage >= state.pageCount) {
      return;
    }
    await pdfViewerController.goToPage(pageNumber: state.currentPage + 1);
  }

  Future<void> jumpToPage(String rawValue) async {
    if (!state.hasDocument || state.pageCount == 0) {
      return;
    }
    final int? pageNumber = int.tryParse(rawValue);
    if (pageNumber == null) {
      _setPageText('${state.currentPage}');
      return;
    }
    final int safePage = pageNumber.clamp(1, state.pageCount);
    _setPageText('$safePage');
    await pdfViewerController.goToPage(pageNumber: safePage);
  }

  Future<void> jumpToOutlinePage(PdfOutlineEntry entry) async {
    if (!state.hasDocument) {
      return;
    }
    _pinnedOutlineId = entry.id;
    _pinnedOutlinePage = entry.pageNumber;
    _pendingOutlineTargetPage = entry.pageNumber;
    _applyState(state.copyWith(selectedOutlineId: entry.id));
    await pdfViewerController.goToPage(pageNumber: entry.pageNumber);
  }

  Future<void> zoomIn() async {
    if (!_isViewerReady()) {
      return;
    }
    _applyZoomStep(HomeController._zoomStepFactor);
  }

  Future<void> zoomOut() async {
    if (!_isViewerReady()) {
      return;
    }
    _applyZoomStep(1 / HomeController._zoomStepFactor);
  }

  Future<void> fitWidth() async {
    if (!_isViewerReady()) {
      return;
    }
    final Rect? targetRect = _currentFitWidthRect();
    final double? zoom = _currentFitWidthZoom();
    if (targetRect == null || zoom == null) {
      return;
    }
    pdfViewerController.value = pdfViewerController.calcMatrixFor(
      Offset(targetRect.center.dx, pdfViewerController.centerPosition.dy),
      zoom: zoom,
    );
  }

  Future<void> actualSize() async {
    if (!_isViewerReady()) {
      return;
    }
    _applyState(state.copyWith(fitWidthActive: false));
    pdfViewerController.value = pdfViewerController.calcMatrixFor(
      pdfViewerController.centerPosition,
      zoom: 1,
    );
  }

  void _applyZoomStep(double factor) {
    if (state.fitWidthActive) {
      _applyState(state.copyWith(fitWidthActive: false));
    }
    final double nextZoom = (pdfViewerController.currentZoom * factor).clamp(
      pdfViewerController.minScale,
      pdfViewerController.params.maxScale,
    );
    pdfViewerController.value = pdfViewerController.calcMatrixFor(
      pdfViewerController.centerPosition,
      zoom: nextZoom,
    );
  }

  void toggleSpreadMode() {
    _applyState(state.copyWith(spreadMode: !state.spreadMode));
    if (_isViewerReady()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_isViewerReady()) {
          return;
        }
        fitWidth();
      });
    }
  }

  void _handleViewerChanged() {
    if (!_isViewerReady()) {
      return;
    }

    final int currentPage = pdfViewerController.pageNumber ?? state.currentPage;
    final double zoom = pdfViewerController.currentZoom;
    if (currentPage == state.currentPage && (zoom - state.zoom).abs() < 0.001) {
      return;
    }

    _applyState(
      state.copyWith(
        currentPage: currentPage,
        zoom: zoom,
        selectedOutlineId: _selectedOutlineIdForPage(currentPage),
      ),
    );
    _setPageText('$currentPage');
  }

  void updateRenderAreaWidth(
    double width, {
    bool reserveScrollbarInset = true,
  }) {
    _renderAreaWidth = width;
    _reserveFitWidthScrollbarInset = reserveScrollbarInset;
  }

  bool get shouldLockHorizontalPan {
    if (!_isViewerReady()) {
      return true;
    }
    final double? fitWidthZoom = _currentFitWidthZoom();
    if (fitWidthZoom == null || fitWidthZoom <= 0) {
      return false;
    }
    return pdfViewerController.currentZoom <= fitWidthZoom * 1.01;
  }

  Rect? _currentFitWidthRect() {
    final Rect? currentPageRect = _currentPageRect();
    if (currentPageRect == null) {
      return null;
    }
    if (!state.spreadMode) {
      return currentPageRect;
    }

    final List<Rect> pageLayouts = pdfViewerController.layout.pageLayouts;
    final int currentPageNumber = pdfViewerController.pageNumber!;
    final int pageIndex = currentPageNumber - 1;
    final int adjacentPageIndex =
        currentPageNumber.isOdd ? pageIndex + 1 : pageIndex - 1;
    if (adjacentPageIndex < 0 || adjacentPageIndex >= pageLayouts.length) {
      return currentPageRect;
    }
    return currentPageRect.expandToInclude(
      pageLayouts[adjacentPageIndex].inflate(pdfViewerController.params.margin),
    );
  }

  Rect? _currentPageRect() {
    final int? currentPageNumber = pdfViewerController.pageNumber;
    if (currentPageNumber == null) {
      return null;
    }
    final List<Rect> pageLayouts = pdfViewerController.layout.pageLayouts;
    if (currentPageNumber < 1 || currentPageNumber > pageLayouts.length) {
      return null;
    }
    return pageLayouts[currentPageNumber - 1]
        .inflate(pdfViewerController.params.margin);
  }

  double? _currentFitWidthZoom() {
    final Rect? targetRect = _currentFitWidthRect();
    final double scrollbarInset = _reserveFitWidthScrollbarInset
        ? HomeController._kScrollbarWidth
        : 0;
    final double availableWidth = _renderAreaWidth > 0
        ? _renderAreaWidth - scrollbarInset
        : pdfViewerController.viewSize.width - scrollbarInset;
    if (targetRect == null || targetRect.width <= 0 || availableWidth <= 0) {
      return null;
    }
    return availableWidth / targetRect.width;
  }

  bool _isViewerReady() {
    return state.hasDocument && pdfViewerController.isReady;
  }
}
