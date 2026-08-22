part of 'home_controller.dart';

extension HomeControllerFileManager on HomeController {
  void handleOpenFile() {
    unawaited(openPickedFile());
  }

  void handleOpenRecentFile(String filePath) {
    debugPrint('[plume_pdf] handleOpenRecentFile: $filePath');
    unawaited(openFilePath(filePath));
  }

  void deleteRecentFile(String filePath) {
    unawaited(_deleteRecentFile(filePath));
  }

  void recoverRecentFile(String filePath) {
    unawaited(_recoverRecentFile(filePath));
  }

  Future<void> _handleOpenedFiles(List<String> filePaths) async {
    final String? pdfPath = filePaths.cast<String?>().firstWhere(
      (String? item) => item != null && _isPdfFile(item),
      orElse: () => null,
    );
    if (pdfPath == null) {
      _showError('只能打开 .pdf 文件。');
      return;
    }
    debugPrint('[plume_pdf] open file from macOS: $pdfPath');
    await openFilePath(pdfPath);
  }

  void setDraggingLocalFile(bool dragging) {
    if (state.draggingLocalFile == dragging) {
      return;
    }
    _applyState(state.copyWith(draggingLocalFile: dragging));
  }

  Future<void> handleDroppedFiles(List<String> filePaths) async {
    setDraggingLocalFile(false);
    final String? pdfPath = filePaths.cast<String?>().firstWhere(
      (String? filePath) => filePath != null && _isPdfFile(filePath),
      orElse: () => null,
    );
    if (pdfPath == null) {
      _showError('只能拖入 .pdf 文件。');
      return;
    }
    debugPrint('[plume_pdf] open file from drop: $pdfPath');
    await openFilePath(pdfPath);
  }

  Future<void> openPickedFile() async {
    try {
      debugPrint('[plume_pdf] openPickedFile invoked');
      final String? selectedPath = await _filePicker.pickPdfFile();
      if (selectedPath == null) {
        debugPrint('[plume_pdf] openPickedFile canceled');
        return;
      }
      if (!_isPdfFile(selectedPath)) {
        _applyState(
          state.copyWith(
            loading: false,
            errorMessage: '请选择 .pdf 文件。',
          ),
        );
        return;
      }
      debugPrint('[plume_pdf] openPickedFile selected: $selectedPath');
      await openFilePath(selectedPath);
    } catch (error, stackTrace) {
      debugPrint('[plume_pdf] openPickedFile failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      _applyState(
        state.copyWith(
          loading: false,
          errorMessage: '打开文件面板失败：$error',
        ),
      );
    }
  }

  bool _isPdfFile(String filePath) {
    return path.extension(filePath).toLowerCase() == '.pdf';
  }

  Future<void> openFilePath(String filePath) async {
    debugPrint('[plume_pdf] openFilePath: $filePath');
    if (filePath.isEmpty) {
      return;
    }
    _aiSessionId++;
    _aiChatHistory.clear();
    _pinnedOutlineId = null;
    _pinnedOutlinePage = null;
    _pendingOutlineTargetPage = null;
    final File file = File(filePath);
    if (!await file.exists()) {
      await _markRecentFileUnavailable(filePath);
      _showError('文件不存在，可能已经被移动或删除。');
      return;
    }

    final PdfRecentFile? previousRecord =
        _store.findByPath(state.recentFiles, filePath);
    final int initialPage = previousRecord?.lastPage ?? 1;

    _applyState(_buildLoadingState(filePath, initialPage));
    _setPageText('$initialPage');
    await _rememberRecentFile(filePath, lastPage: initialPage);
    await _markRecentFileAvailable(filePath);
  }

  void showRecentFiles() {
    final PdfAiPanelState aiPanelState = state.aiPanelState;
    _applyState(
      state.copyWith(
        filePath: null,
        fileName: null,
        loading: false,
        errorMessage: null,
        currentPage: 1,
        pageCount: 0,
        initialPage: 1,
        selectedOutlineId: null,
        outline: const <PdfOutlineEntry>[],
        aiSelectionMode: false,
        aiSelection: null,
        aiPanelState: aiPanelState.copyWith(
          loading: false,
          actionLabel: null,
          actionId: null,
          result: null,
          errorMessage: null,
        ),
      ),
    );
    _aiChatHistory.clear();
    unawaited(_refreshRecentFileAvailability(state.recentFiles));
  }

  Future<void> reopenFromError() async {
    if (state.filePath == null) {
      await openPickedFile();
      return;
    }
    await openFilePath(state.filePath!);
  }

  Future<void> _loadRecentFiles() async {
    final List<PdfRecentFile> files = await _store.loadRecentFiles();
    _applyState(state.copyWith(recentFiles: files));
    await _refreshRecentFileAvailability(files);
  }

  Future<void> _deleteRecentFile(String filePath) async {
    final List<PdfRecentFile> nextFiles = await _store.removeFile(
      state.recentFiles,
      filePath,
    );
    final Set<String> nextUnavailablePaths = Set<String>.from(
      state.unavailableRecentFilePaths,
    )..remove(filePath);
    _applyState(
      state.copyWith(
        recentFiles: nextFiles,
        unavailableRecentFilePaths: nextUnavailablePaths,
      ),
    );
  }

  Future<void> _recoverRecentFile(String filePath) async {
    final String? selectedPath = await _filePicker.pickPdfFile();
    if (selectedPath == null || !_isPdfFile(selectedPath)) {
      return;
    }
    final PdfRecentFile? previousRecord =
        _store.findByPath(state.recentFiles, filePath);
    final List<PdfRecentFile> nextFiles = <PdfRecentFile>[
      if (previousRecord != null)
        previousRecord.copyWith(
          path: selectedPath,
          name: path.basename(selectedPath),
          lastOpenedAt: DateTime.now(),
          coverPath: null,
        ),
      ...state.recentFiles.where(
        (PdfRecentFile item) =>
            item.path != filePath && item.path != selectedPath,
      ),
    ];
    if (previousRecord != null) {
      await _store.saveRecentFiles(nextFiles);
      final Set<String> nextUnavailablePaths = Set<String>.from(
        state.unavailableRecentFilePaths,
      )
        ..remove(filePath)
        ..remove(selectedPath);
      _applyState(
        state.copyWith(
          recentFiles: nextFiles,
          unavailableRecentFilePaths: nextUnavailablePaths,
        ),
      );
    }
    await openFilePath(selectedPath);
  }

  Future<void> _loadAiApiKey() async {
    final String deepSeekApiKey = await _deepSeekSettingsStore.loadApiKey();
    _applyState(
      state.copyWith(
        aiPanelState: state.aiPanelState.copyWith(
          apiKey: deepSeekApiKey,
        ),
      ),
    );
  }

  Future<void> _loadBackgroundTheme() async {
    final PdfBackgroundTheme theme = await _store.loadBackgroundTheme();
    _applyState(state.copyWith(backgroundTheme: theme));
  }

  Future<void> setBackgroundTheme(PdfBackgroundTheme theme) async {
    _applyState(state.copyWith(backgroundTheme: theme));
    await _store.saveBackgroundTheme(theme);
  }

  Future<void> _rememberRecentFile(
    String filePath, {
    required int lastPage,
  }) async {
    final PdfRecentFile? existing =
        _store.findByPath(state.recentFiles, filePath);
    String? coverPath = existing?.coverPath;
    if (coverPath == null || coverPath.isEmpty) {
      try {
        coverPath = await PdfCoverCache.instance.getOrGenerateCover(filePath);
      } catch (_) {
        coverPath = null;
      }
    }
    final List<PdfRecentFile> nextFiles = await _store.rememberFile(
      state.recentFiles,
      filePath,
      lastPage: lastPage,
      coverPath: coverPath,
    );
    _applyState(state.copyWith(recentFiles: nextFiles));
  }

  Future<void> _refreshRecentFileAvailability(List<PdfRecentFile> files) async {
    final int checkId = ++_recentFilesCheckId;
    final List<String> unavailablePaths = <String>[];
    for (final PdfRecentFile file in files) {
      if (!await File(file.path).exists()) {
        unavailablePaths.add(file.path);
      }
    }
    if (checkId != _recentFilesCheckId) {
      return;
    }
    _applyState(
      state.copyWith(
        unavailableRecentFilePaths: unavailablePaths.toSet(),
      ),
    );
  }

  Future<void> _markRecentFileUnavailable(String filePath) async {
    final Set<String> nextUnavailablePaths = Set<String>.from(
      state.unavailableRecentFilePaths,
    )..add(filePath);
    _applyState(state.copyWith(unavailableRecentFilePaths: nextUnavailablePaths));
  }

  Future<void> _markRecentFileAvailable(String filePath) async {
    if (!state.unavailableRecentFilePaths.contains(filePath)) {
      return;
    }
    final Set<String> nextUnavailablePaths = Set<String>.from(
      state.unavailableRecentFilePaths,
    )..remove(filePath);
    _applyState(state.copyWith(unavailableRecentFilePaths: nextUnavailablePaths));
  }

  void _scheduleProgressSave() {
    if (state.filePath == null) {
      return;
    }
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 400), () async {
      await _rememberRecentFile(state.filePath!, lastPage: state.currentPage);
    });
  }

  Future<void> _loadOutline(PdfDocument document) async {
    try {
      final List<PdfOutlineNode> nodes = await document.loadOutline();
      final List<PdfOutlineEntry> entries = _outlineMapper.flatten(nodes);
      _applyState(
        state.copyWith(
          outline: entries,
          selectedOutlineId: _selectedOutlineIdForPage(state.currentPage),
        ),
      );
    } catch (_) {
      _applyState(
        state.copyWith(
          outline: const <PdfOutlineEntry>[],
          selectedOutlineId: null,
        ),
      );
    }
  }

  String? _outlineIdForPage(int pageNumber) {
    if (state.outline.isEmpty) {
      return null;
    }

    PdfOutlineEntry? matchedEntry;
    for (final PdfOutlineEntry entry in state.outline) {
      if (entry.pageNumber > pageNumber) {
        break;
      }
      matchedEntry = entry;
    }
    return matchedEntry?.id;
  }

  String? _selectedOutlineIdForPage(int pageNumber) {
    if (_pendingOutlineTargetPage != null) {
      if (pageNumber != _pendingOutlineTargetPage) {
        return state.selectedOutlineId ?? _pinnedOutlineId;
      }
      _pendingOutlineTargetPage = null;
    }
    if (_pinnedOutlineId != null && _pinnedOutlinePage == pageNumber) {
      return _pinnedOutlineId;
    }
    if (_pinnedOutlinePage != null && _pinnedOutlinePage != pageNumber) {
      _pinnedOutlineId = null;
      _pinnedOutlinePage = null;
    }
    return _outlineIdForPage(pageNumber);
  }
}
