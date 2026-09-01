import 'package:pdfrx/pdfrx.dart';

enum PdfAiSelectionType {
  area,
}

class PdfAiSelectionRegion {
  const PdfAiSelectionRegion({
    required this.pageNumber,
    required this.bounds,
  });

  final int pageNumber;
  final PdfRect bounds;
}

class PdfAiSelection {
  const PdfAiSelection._({
    required this.regions,
    this.extractedText,
  }) : type = PdfAiSelectionType.area;

  factory PdfAiSelection.area({
    required int pageNumber,
    required PdfRect bounds,
    String? extractedText,
  }) {
    return PdfAiSelection._(
      regions: <PdfAiSelectionRegion>[
        PdfAiSelectionRegion(pageNumber: pageNumber, bounds: bounds),
      ],
      extractedText: extractedText,
    );
  }

  factory PdfAiSelection.regions({
    required List<PdfAiSelectionRegion> regions,
    String? extractedText,
  }) {
    assert(regions.isNotEmpty);
    return PdfAiSelection._(
      regions: List<PdfAiSelectionRegion>.unmodifiable(regions),
      extractedText: extractedText,
    );
  }

  final PdfAiSelectionType type;

  /// 一个 viewer 级矩形可以同时穿过多页；每个 region 保存它与对应 PDF 页
  /// 的实际交集。regions 按页码升序保存，且全局一次只存在一个 selection。
  final List<PdfAiSelectionRegion> regions;
  final String? extractedText;

  /// 兼容原有单页调用；跨页时返回第一段。
  int get pageNumber => regions.first.pageNumber;
  PdfRect get bounds => regions.first.bounds;

  int get firstPageNumber => regions.first.pageNumber;
  int get lastPageNumber => regions.last.pageNumber;
  bool get spansMultiplePages => firstPageNumber != lastPageNumber;

  String get summary {
    if (!spansMultiplePages) {
      final PdfRect value = regions.first.bounds;
      return '第 $firstPageNumber 页区域 ${value.width.toStringAsFixed(0)} x '
          '${value.height.toStringAsFixed(0)}';
    }
    return '第 $firstPageNumber-$lastPageNumber 页跨页区域（${regions.length} 页）';
  }

  PdfAiSelection copyWith({
    List<PdfAiSelectionRegion>? regions,
    Object? extractedText = _sentinel,
  }) {
    return PdfAiSelection.regions(
      regions: regions ?? this.regions,
      extractedText: identical(extractedText, _sentinel)
          ? this.extractedText
          : extractedText as String?,
    );
  }
}

const Object _sentinel = Object();
