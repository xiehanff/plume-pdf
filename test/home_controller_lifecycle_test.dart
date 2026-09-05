import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:plume_pdf/app/modules/home/controllers/home_controller.dart';
import 'package:plume_pdf/app/modules/pdf_ai/models/pdf_ai_panel_state.dart';
import 'package:plume_pdf/app/modules/pdf_ai/models/pdf_ai_selection.dart';
import 'package:plume_pdf/app/modules/home/models/pdf_reader_state.dart';

void main() {
  test('selection changes never mutate host AI preflight state', () {
    final HomeController controller = HomeController();
    final PdfAiSelection initialSelection = PdfAiSelection.area(
      pageNumber: 1,
      bounds: const PdfRect(10, 100, 120, 20),
    );
    const PdfAiPanelState runningPreflight = PdfAiPanelState(
      apiKey: 'cached-key',
      loading: true,
    );
    controller.state = PdfReaderState(
      aiSelectionMode: true,
      aiSelection: initialSelection,
      aiPanelState: runningPreflight,
    );

    controller.onAiSelectionChanged(null);

    expect(controller.state.aiSelection, isNull);
    expect(controller.state.aiPanelState, same(runningPreflight));
    expect(controller.state.aiPanelState.loading, isTrue);
    expect(controller.state.aiPanelState.apiKey, 'cached-key');

    final PdfAiSelection nextSelection = PdfAiSelection.area(
      pageNumber: 2,
      bounds: const PdfRect(20, 180, 160, 40),
    );
    controller.onAiSelectionChanged(nextSelection);

    expect(controller.state.aiSelection, same(nextSelection));
    expect(controller.state.aiPanelState, same(runningPreflight));

    controller.onClose();
  });

  test('stale viewer ready and error callbacks cannot mutate current document', () {
    final HomeController controller = HomeController();
    controller.state = const PdfReaderState(
      filePath: '/tmp/current.pdf',
      loading: true,
    );

    controller.onViewerReady('/tmp/old.pdf');
    controller.onLoadError(
      '/tmp/old.pdf',
      StateError('stale viewer error'),
      null,
    );

    expect(controller.state.filePath, '/tmp/current.pdf');
    expect(controller.state.loading, isTrue);
    expect(controller.state.errorMessage, isNull);

    controller.onLoadError(
      '/tmp/current.pdf',
      StateError('current viewer error'),
      null,
    );
    expect(controller.state.errorMessage, contains('current viewer error'));

    controller.onClose();
  });

  test('leaving a document ends host AI preflight and keeps API key', () {
    final HomeController controller = HomeController();
    controller.state = const PdfReaderState(
      filePath: '/tmp/current.pdf',
      aiSelectionMode: true,
      aiPanelState: PdfAiPanelState(
        apiKey: 'cached-key',
        loading: true,
      ),
    );

    controller.showRecentFiles();

    expect(controller.state.filePath, isNull);
    expect(controller.state.aiSelectionMode, isFalse);
    expect(controller.state.aiPanelState.apiKey, 'cached-key');
    expect(controller.state.aiPanelState.loading, isFalse);

    controller.onClose();
  });
}
