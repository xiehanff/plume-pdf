import 'package:flutter_test/flutter_test.dart';
import 'package:plume_pdf/app/modules/home/models/pdf_ai_context.dart';
import 'package:plume_pdf/app/modules/home/models/pdf_outline_entry.dart';
import 'package:plume_pdf/app/modules/home/services/ai_prompts.dart';

void main() {
  test('从中文和英文消息中识别指定页码', () {
    expect(PdfAiContext.requestedPageFromMessage('请读取第 12 页'), 12);
    expect(PdfAiContext.requestedPageFromMessage('请总结 page 18 的内容'), 18);
    expect(PdfAiContext.requestedPageFromMessage('请看 p. 7'), 7);
    expect(PdfAiContext.requestedPageFromMessage('请总结当前页'), isNull);
  });

  test('文档上下文包含书籍元数据、目录、当前页和指定页内容', () {
    const PdfAiContext context = PdfAiContext(
      title: 'sample-book.pdf',
      fileSizeBytes: 1024 * 1024 * 2,
      directory: r'D:\books',
      currentPage: 4,
      pageCount: 120,
      outline: <PdfOutlineEntry>[
        PdfOutlineEntry(id: 'chapter-1', title: '第一章', pageNumber: 2, depth: 0),
      ],
      currentPageText: '当前页正文',
      requestedPage: 20,
      requestedPageText: '指定页正文',
    );

    final String prompt = AiPrompts.documentContextPrompt(context);
    expect(prompt, contains('标题：sample-book.pdf'));
    expect(prompt, contains('文件大小：2.0 MB'));
    expect(prompt, contains('当前页码：第 4 页'));
    expect(prompt, contains('总页数：120 页'));
    expect(prompt, contains('第一章'));
    expect(prompt, contains('当前页正文'));
    expect(prompt, contains('用户明确指定的第 20 页全文'));
    expect(prompt, contains('指定页正文'));
  });

  test('长目录只发送当前章节附近的有限条目', () {
    final List<PdfOutlineEntry> outline = List<PdfOutlineEntry>.generate(200, (
      int index,
    ) {
      final int pageNumber = index + 1;
      return PdfOutlineEntry(
        id: 'chapter-$pageNumber',
        title: '章节-$pageNumber',
        pageNumber: pageNumber,
        depth: 0,
      );
    });
    final PdfAiContext context = PdfAiContext(
      title: 'large-outline.pdf',
      fileSizeBytes: 1024,
      directory: r'D:\books',
      currentPage: 100,
      pageCount: 200,
      outline: outline,
      currentPageText: '当前页正文',
    );

    final String prompt = AiPrompts.documentContextPrompt(context);
    expect(prompt, contains('- 章节-100（第 100 页）'));
    expect(prompt, contains('展示 20/200 项'));
    expect(prompt, isNot(contains('- 章节-1（第 1 页）')));
    expect(prompt, isNot(contains('- 章节-200（第 200 页）')));
  });
}
