import 'package:pdfrx/pdfrx.dart';

import '../models/pdf_outline_entry.dart';

class PdfOutlineMapper {
  const PdfOutlineMapper();

  List<PdfOutlineEntry> flatten(List<PdfOutlineNode> nodes) {
    return _flatten(nodes);
  }

  List<PdfOutlineEntry> _flatten(
    List<PdfOutlineNode> nodes, {
    int depth = 0,
    String parentId = '',
  }) {
    final List<PdfOutlineEntry> entries = <PdfOutlineEntry>[];
    for (int index = 0; index < nodes.length; index++) {
      final PdfOutlineNode node = nodes[index];
      final String nodeId =
          parentId.isEmpty ? '$depth-$index' : '$parentId-$index';
      final int? pageNumber = node.dest?.pageNumber;

      if (pageNumber != null && pageNumber > 0) {
        entries.add(
          PdfOutlineEntry(
            id: nodeId,
            title: _normalizeTitle(node.title),
            pageNumber: pageNumber,
            depth: depth,
          ),
        );
      }

      entries.addAll(
        _flatten(
          node.children,
          depth: depth + 1,
          parentId: nodeId,
        ),
      );
    }
    return entries;
  }

  String _normalizeTitle(String rawTitle) {
    final String normalized = rawTitle.trim();
    return normalized.isEmpty ? 'Untitled' : normalized;
  }
}
