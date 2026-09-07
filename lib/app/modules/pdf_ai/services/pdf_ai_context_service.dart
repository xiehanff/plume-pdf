import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:path/path.dart' as path;
import 'package:pdfrx/pdfrx.dart';

import '../../reader/models/pdf_outline_entry.dart';
import '../models/pdf_ai_context.dart';
import '../models/pdf_ai_selection.dart';
import 'macos_ocr_service.dart';

/// PDF 上下文提取层：从当前文档提取选区文本、选区截图、页面全文
/// 与文档级 AI 上下文，供 AI 会话适配层组装请求使用。
class PdfAiContextService {
  PdfAiContextService({
    required PdfViewerController viewerController,
    required MacosOcrService ocrService,
  }) : _viewerController = viewerController,
       _ocrService = ocrService;

  final PdfViewerController _viewerController;
  final MacosOcrService _ocrService;

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

  /// 跨页 selection 会按页顺序提取每个 region 的文本，并保持为一次请求。
  Future<String> extractSelectionText(PdfAiSelection selection) async {
    return await _viewerController.useDocument<String>((
          PdfDocument document,
        ) async {
          final List<String> chunks = <String>[];
          for (final PdfAiSelectionRegion region in selection.regions) {
            if (region.pageNumber < 1 ||
                region.pageNumber > document.pages.length) {
              continue;
            }
            final PdfPageText pageText = await document
                .pages[region.pageNumber - 1]
                .loadText();
            final String text = pageText.fragments
                .where(
                  (PdfPageTextFragment fragment) =>
                      _intersects(region.bounds, fragment.bounds),
                )
                .map((PdfPageTextFragment fragment) => fragment.text.trim())
                .where((String value) => value.isNotEmpty)
                .join('\n')
                .trim();
            if (text.isEmpty) continue;
            chunks.add(
              selection.spansMultiplePages
                  ? '【第 ${region.pageNumber} 页】\n$text'
                  : text,
            );
          }
          return chunks.join('\n');
        }) ??
        '';
  }

  /// 单页时仍返回该页全文；跨页时返回所有被选中页的上下文。
  Future<String?> extractPageContext(PdfAiSelection selection) async {
    return await _viewerController.useDocument<String?>((
      PdfDocument document,
    ) async {
      final List<String> chunks = <String>[];
      final Set<int> visited = <int>{};
      for (final PdfAiSelectionRegion region in selection.regions) {
        if (!visited.add(region.pageNumber) ||
            region.pageNumber < 1 ||
            region.pageNumber > document.pages.length) {
          continue;
        }
        final String fullText = await _loadPdfPageText(
          document,
          region.pageNumber,
        );
        if (fullText.isEmpty) continue;
        chunks.add(
          selection.spansMultiplePages
              ? '【第 ${region.pageNumber} 页全文】\n$fullText'
              : fullText,
        );
      }
      final String result = chunks.join('\n').trim();
      return result.isEmpty ? null : result;
    });
  }

  /// 将一个跨页框选对应的多个页面裁剪图纵向拼成一张 PNG。
  /// 对视觉模型和 OCR 来说仍然是一份 selection，而不是多次请求。
  Future<Uint8List?> extractSelectionImageBytes(
    PdfAiSelection selection,
  ) async {
    return _viewerController.useDocument<Uint8List?>((
      PdfDocument document,
    ) async {
      final List<ui.Image> images = <ui.Image>[];
      try {
        for (final PdfAiSelectionRegion region in selection.regions) {
          final ui.Image? image = await _renderSelectionRegion(document, region);
          if (image != null) {
            images.add(image);
          }
        }
        if (images.isEmpty) return null;
        if (images.length == 1) {
          return _imageToPng(images.first);
        }

        final int width = images.fold<int>(
          1,
          (int value, ui.Image image) => math.max(value, image.width),
        );
        final int height = images.fold<int>(
          0,
          (int value, ui.Image image) => value + image.height,
        );
        if (height <= 0) return null;

        final ui.PictureRecorder recorder = ui.PictureRecorder();
        final ui.Canvas canvas = ui.Canvas(recorder);
        double y = 0;
        for (final ui.Image image in images) {
          final double x = (width - image.width) / 2;
          canvas.drawImage(image, ui.Offset(x, y), ui.Paint());
          y += image.height;
        }
        final ui.Picture picture = recorder.endRecording();
        final ui.Image combined = await picture.toImage(width, height);
        picture.dispose();
        try {
          return await _imageToPng(combined);
        } finally {
          combined.dispose();
        }
      } finally {
        for (final ui.Image image in images) {
          image.dispose();
        }
      }
    });
  }

  Future<ui.Image?> _renderSelectionRegion(
    PdfDocument document,
    PdfAiSelectionRegion region,
  ) async {
    if (region.pageNumber < 1 || region.pageNumber > document.pages.length) {
      return null;
    }
    final PdfPage page = document.pages[region.pageNumber - 1];
    const double scale = 3;
    final double fullWidth = page.width * scale;
    final double fullHeight = page.height * scale;
    final int maxX = math.max(0, fullWidth.ceil() - 1);
    final int maxY = math.max(0, fullHeight.ceil() - 1);
    final int x = (region.bounds.left * scale).floor().clamp(0, maxX);
    final int y = ((page.height - region.bounds.top) * scale)
        .floor()
        .clamp(0, maxY);
    final int width = (region.bounds.width * scale).ceil().clamp(
      1,
      fullWidth.ceil(),
    );
    final int height = (region.bounds.height * scale).ceil().clamp(
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
    if (rendered == null) return null;
    try {
      return await rendered.createImage();
    } finally {
      rendered.dispose();
    }
  }

  Future<Uint8List?> _imageToPng(ui.Image image) async {
    final ByteData? data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data?.buffer.asUint8List();
  }

  int _safePdfPage(int pageNumber, int pageCount) {
    if (pageNumber < 1) return 1;
    if (pageNumber > pageCount) return pageCount;
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
