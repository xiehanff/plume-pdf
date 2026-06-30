import 'package:pdfrx/pdfrx.dart';

enum PdfAiSelectionType {
  area,
}

class PdfAiSelection {
  const PdfAiSelection.area({
    required this.pageNumber,
    required this.bounds,
    this.extractedText,
  }) : type = PdfAiSelectionType.area;

  final PdfAiSelectionType type;
  final int pageNumber;
  final PdfRect bounds;
  final String? extractedText;

  String get summary {
    return '第 $pageNumber 页区域 ${bounds.width.toStringAsFixed(0)} x '
        '${bounds.height.toStringAsFixed(0)}';
  }

  PdfAiSelection copyWith({
    int? pageNumber,
    PdfRect? bounds,
    Object? extractedText = _sentinel,
  }) {
    return PdfAiSelection.area(
      pageNumber: pageNumber ?? this.pageNumber,
      bounds: bounds ?? this.bounds,
      extractedText: identical(extractedText, _sentinel)
          ? this.extractedText
          : extractedText as String?,
    );
  }
}

const Object _sentinel = Object();
