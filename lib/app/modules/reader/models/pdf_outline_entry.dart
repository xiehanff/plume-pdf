class PdfOutlineEntry {
  const PdfOutlineEntry({
    required this.id,
    required this.title,
    required this.pageNumber,
    required this.depth,
  });

  final String id;
  final String title;
  final int pageNumber;
  final int depth;
}
