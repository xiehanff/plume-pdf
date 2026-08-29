import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:path/path.dart' as path;
import 'package:pdfrx/pdfrx.dart';

import '../models/pdf_ai_context.dart';
import '../models/pdf_ai_selection.dart';
import '../models/pdf_outline_entry.dart';
import 'macos_ocr_service.dart';

/// PDF 上下文提取层：从当前文档提取选区文本、选区截图、页面全文
/// 与文档级 AI 上下文，供 Agent 会话层组装请求使用。
class PdfAiContextService {
  PdfAiContextService({
    required PdfViewerController viewerController,
    required MacosOcrService ocrService,
  }) : _viewerController = viewerController,
       _ocrService = ocrService;

  final PdfViewerController _viewerController;
  final MacosOcrService _ocrService;

  /// 在每次对话请求前读取当前打开 PDF 的元数据、目录和页面正文。
  ///
  /// 文档上下文不写入会话历史，而是作为本次请求的 system prompt
  /// 附加内容传给模型，避免同一份页面全文在多轮历史中不断复制。
  Future<PdfAiContext?> buildDocumentContext({
    required String? filePath,
    required String? fileName,
    required int currentPage,
    required List<PdfOutlineEntry> outline,
    required String message,
  }) async {
    if (filePath == null || filePath.trim().isEmpty) {
      return null;
    }

    final int? requestedPage = PdfAiContext.requestedPageFromMessage(message);
    final List<PdfOutlineEntry> outlineEntries =
        List<PdfOutlineEntry>.unmodifiable(outline);
    final String title = fileName?.trim().isNotEmpty == true
        ? fileName!.trim()
        : path.basename(filePath);

    return _viewerController.useDocument<PdfAiContext?>((
      PdfDocument document,
    ) async {
      final int pageCount = document.pages.length;
      if (pageCount <= 0) {
        return null;
      }
      final int safeCurrentPage = _safePdfPage(currentPage, pageCount);
      final String currentPageText = await _loadPdfPageText(
        document,
        safeCurrentPage,
      );

      String? requestedPageText;
      if (requestedPage != null &&
          requestedPage >= 1 &&
          requestedPage <= pageCount) {
        requestedPageText = requestedPage == safeCurrentPage
            ? currentPageText
            : await _loadPdfPageText(document, requestedPage);
      }

      return PdfAiContext(
        title: title,
        currentPage: safeCurrentPage,
        pageCount: pageCount,
        outline: outlineEntries,
        currentPageText: currentPageText,
        requestedPage: requestedPage,
        requestedPageText: requestedPageText,
      );
    });
  }

  /// 提取选区内可直接复制的文本；选区无文本时回退 OCR 识别截图。
  Future<String> resolveSelectionText(
    PdfAiSelection selection, {
    Uint8List? imageBytes,
  }) async {
    final String directText = await extractSelectionText(selection);
    if (directText.trim().isNotEmpty) {
      return directText;
    }

    final Uint8List? bytes =
        imageBytes ?? await extractSelectionImageBytes(selection);
    if (bytes == null || bytes.isEmpty) {
      return '';
    }
    return _ocrService.recognizeText(bytes);
  }

  Future<String> extractSelectionText(PdfAiSelection selection) async {
    return await _viewerController.useDocument<String>((
          PdfDocument document,
        ) async {
          if (selection.pageNumber < 1 ||
              selection.pageNumber > document.pages.length) {
            return '';
          }
          final PdfPageText pageText = await document
              .pages[selection.pageNumber - 1]
              .loadText();
          final Iterable<String> texts = pageText.fragments
              .where(
                (PdfPageTextFragment fragment) =>
                    _intersects(selection.bounds, fragment.bounds),
              )
              .map((PdfPageTextFragment fragment) => fragment.text.trim())
              .where((String text) => text.isNotEmpty);
          return texts.join('\n');
        }) ??
        '';
  }

  Future<String?> extractPageContext(PdfAiSelection selection) async {
    return await _viewerController.useDocument<String?>((
      PdfDocument document,
    ) async {
      if (selection.pageNumber < 1 ||
          selection.pageNumber > document.pages.length) {
        return null;
      }
      final PdfPageText pageText = await document
          .pages[selection.pageNumber - 1]
          .loadText();
      final String fullText = pageText.fragments
          .map((PdfPageTextFragment f) => f.text.trim())
          .where((String t) => t.isNotEmpty)
          .join('\n');
      return fullText.trim().isEmpty ? null : fullText;
    });
  }

  Future<Uint8List?> extractSelectionImageBytes(
    PdfAiSelection selection,
  ) async {
    return _viewerController.useDocument<Uint8List?>((
      PdfDocument document,
    ) async {
      if (selection.pageNumber < 1 ||
          selection.pageNumber > document.pages.length) {
        return null;
      }
      final PdfPage page = document.pages[selection.pageNumber - 1];
      const double scale = 3;
      final double fullWidth = page.width * scale;
      final double fullHeight = page.height * scale;
      final int maxX = math.max(0, fullWidth.ceil() - 1);
      final int maxY = math.max(0, fullHeight.ceil() - 1);
      final int x = (selection.bounds.left * scale).floor().clamp(0, maxX);
      final int y = ((page.height - selection.bounds.top) * scale)
          .floor()
          .clamp(0, maxY);
      final int width = (selection.bounds.width * scale).ceil().clamp(
        1,
        fullWidth.ceil(),
      );
      final int height = (selection.bounds.height * scale).ceil().clamp(
        1,
        fullHeight.ceil(),
      );
      final int safeWidth = width.clamp(1, math.max(1, fullWidth.ceil() - x));
      final int safeHeight = height.clamp(
        1,
        math.max(1, fullHeight.ceil() - y),
      );
      final PdfImage? rendered = await page.render(
        x: x,
        y: y,
        width: safeWidth,
        height: safeHeight,
        fullWidth: fullWidth,
        fullHeight: fullHeight,
      );
      if (rendered == null) {
        return null;
      }

      final ui.Image image = await rendered.createImage();
      rendered.dispose();
      final ByteData? data = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      image.dispose();
      return data?.buffer.asUint8List();
    });
  }

  int _safePdfPage(int pageNumber, int pageCount) {
    if (pageNumber < 1) {
      return 1;
    }
    if (pageNumber > pageCount) {
      return pageCount;
    }
    return pageNumber;
  }

  Future<String> _loadPdfPageText(PdfDocument document, int pageNumber) async {
    try {
      final PdfPageText pageText = await document.pages[pageNumber - 1]
          .loadText();
      return pageText.fragments
          .map((PdfPageTextFragment fragment) => fragment.text.trim())
          .where((String text) => text.isNotEmpty)
          .join('\n')
          .trim();
    } catch (_) {
      return '';
    }
  }

  bool _intersects(PdfRect a, PdfRect b) {
    return a.left < b.right &&
        a.right > b.left &&
        a.bottom < b.top &&
        a.top > b.bottom;
  }
}
