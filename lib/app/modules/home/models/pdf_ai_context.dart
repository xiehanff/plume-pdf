import 'pdf_outline_entry.dart';

class PdfAiContext {
  const PdfAiContext({
    required this.title,
    required this.currentPage,
    required this.pageCount,
    required this.outline,
    required this.currentPageText,
    this.requestedPage,
    this.requestedPageText,
  });

  final String title;
  final int currentPage;
  final int pageCount;
  final List<PdfOutlineEntry> outline;
  final String currentPageText;
  final int? requestedPage;
  final String? requestedPageText;

  PdfOutlineEntry? get currentChapter {
    PdfOutlineEntry? matchedEntry;
    for (final PdfOutlineEntry entry in outline) {
      if (entry.pageNumber <= currentPage) {
        matchedEntry = entry;
      }
    }
    return matchedEntry;
  }

  static int? requestedPageFromMessage(String message) {
    final List<RegExp> patterns = <RegExp>[
      RegExp(r'第\s*([0-9]+)\s*页'),
      RegExp(r'页码\s*[:：]?\s*([0-9]+)'),
      RegExp(r'\b(?:page|p)\.?\s*#?\s*([0-9]+)\b', caseSensitive: false),
    ];
    for (final RegExp pattern in patterns) {
      final RegExpMatch? match = pattern.firstMatch(message);
      final int? page = int.tryParse(match?.group(1) ?? '');
      if (page != null && page > 0) {
        return page;
      }
    }
    return null;
  }
}
