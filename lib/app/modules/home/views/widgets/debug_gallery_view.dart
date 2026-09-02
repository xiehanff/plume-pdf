import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/ai_sidebar_controller.dart';
import '../../models/pdf_ai_panel_state.dart';
import '../../models/pdf_outline_entry.dart';
import '../../../../theme/app_colors.dart';
import 'ai_sidebar.dart';
import 'empty_reader_view.dart';
import 'error_reader_view.dart';
import 'page_status_bar.dart';
import 'reader_sidebar.dart';

class DebugGalleryView extends StatefulWidget {
  const DebugGalleryView({super.key});

  @override
  State<DebugGalleryView> createState() => _DebugGalleryViewState();
}

class _DebugGalleryViewState extends State<DebugGalleryView> {
  static const String _aiControllerTag = 'debug-gallery-ai-sidebar';

  @override
  void initState() {
    super.initState();
    Get.put(
      AiSidebarController(
        state: const PdfAiPanelState(
          sessionId: 1,
          actionLabel: '翻译',
          result: '这里会展示 DeepSeek 返回的结果。',
        ),
        onApiKeyChanged: (_) {},
        onSaveApiKey: () async {},
        onSendChat: (_) async {},
        onNewSession: () {},
        documentPath: '/path/to/sample.pdf',
      ),
      tag: _aiControllerTag,
    );
  }

  @override
  void dispose() {
    if (Get.isRegistered<AiSidebarController>(tag: _aiControllerTag)) {
      Get.delete<AiSidebarController>(tag: _aiControllerTag);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceBg,
      appBar: AppBar(
        backgroundColor: AppColors.scaffoldBg,
        title: const Text(
          'Debug Gallery',
          style: TextStyle(color: AppColors.textPrimary, fontSize: 16),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textSecondary),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          _sectionTitle('EmptyReaderView'),
          _previewCard(
            child: EmptyReaderView(onOpenFile: () {}),
          ),
          _sectionTitle('ErrorReaderView'),
          _previewCard(
            child: ErrorReaderView(
              message: '文件不存在，可能已经被移动或删除。',
              onRetry: () {},
            ),
          ),
          _previewCard(
            child: ErrorReaderView(
              message: '打开文件面板失败：Permission denied',
              onRetry: () {},
            ),
          ),
          _sectionTitle('PageStatusBar'),
          _previewCard(
            child: const PageStatusBar(
              fileName: 'sample.pdf',
              currentPage: 1,
              pageCount: 100,
              zoom: 1.0,
            ),
          ),
          _previewCard(
            child: const PageStatusBar(
              fileName: null,
              currentPage: 1,
              pageCount: 0,
              zoom: 1.5,
            ),
          ),
          _sectionTitle('ReaderSidebar — Outline'),
          _previewCard(
            height: 360,
            child: ReaderSidebar(
              outline: _sampleOutline,
              selectedOutlineId: '0-0',
              onOpenOutlinePage: (_) {},
            ),
          ),
          _sectionTitle('ReaderSidebar — Empty'),
          _previewCard(
            height: 240,
            child: ReaderSidebar(
              outline: const <PdfOutlineEntry>[],
              selectedOutlineId: null,
              onOpenOutlinePage: (_) {},
            ),
          ),
          _sectionTitle('AiSidebar'),
          _previewCard(
            height: 320,
            child: const AiSidebar(controllerTag: _aiControllerTag),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _previewCard({double? height, required Widget child}) {
    return Container(
      height: height,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: child,
      ),
    );
  }

  static const List<PdfOutlineEntry> _sampleOutline = <PdfOutlineEntry>[
    PdfOutlineEntry(id: '0-0', title: 'Chapter 1 Overview', pageNumber: 1, depth: 0),
    PdfOutlineEntry(id: '0-0-0', title: '1.1 Background', pageNumber: 2, depth: 1),
    PdfOutlineEntry(id: '0-0-1', title: '1.2 Scope', pageNumber: 5, depth: 1),
    PdfOutlineEntry(id: '0-1', title: 'Chapter 2 Design', pageNumber: 10, depth: 0),
    PdfOutlineEntry(id: '0-1-0', title: '2.1 Architecture', pageNumber: 11, depth: 1),
    PdfOutlineEntry(id: '0-1-1', title: '2.2 Interface', pageNumber: 15, depth: 1),
    PdfOutlineEntry(id: '0-2', title: 'Chapter 3 Test', pageNumber: 20, depth: 0),
  ];
}
