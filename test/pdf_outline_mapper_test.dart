import 'package:flutter_test/flutter_test.dart';
import 'package:plume_pdf/app/modules/home/services/pdf_outline_mapper.dart';
import 'package:pdfrx/pdfrx.dart';

void main() {
  const PdfOutlineMapper mapper = PdfOutlineMapper();

  test('flatten builds stable hierarchy ids and skips invalid pages', () {
    const List<PdfOutlineNode> nodes = <PdfOutlineNode>[
      PdfOutlineNode(
        title: ' Chapter 1 ',
        dest: PdfDest(3, PdfDestCommand.fit, null),
        children: <PdfOutlineNode>[
          PdfOutlineNode(
            title: ' ',
            dest: PdfDest(4, PdfDestCommand.fit, null),
            children: <PdfOutlineNode>[],
          ),
        ],
      ),
      PdfOutlineNode(
        title: 'No Page',
        dest: PdfDest(0, PdfDestCommand.fit, null),
        children: <PdfOutlineNode>[],
      ),
    ];

    final entries = mapper.flatten(nodes);

    expect(entries, hasLength(2));
    expect(entries[0].id, '0-0');
    expect(entries[0].title, 'Chapter 1');
    expect(entries[0].pageNumber, 3);
    expect(entries[0].depth, 0);
    expect(entries[1].id, '0-0-0');
    expect(entries[1].title, 'Untitled');
    expect(entries[1].pageNumber, 4);
    expect(entries[1].depth, 1);
  });
}
