import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:plume_pdf/app/modules/home/controllers/home_controller.dart';
import 'package:plume_pdf/app/modules/home/models/pdf_ai_panel_state.dart';
import 'package:plume_pdf/app/modules/home/models/pdf_ai_selection.dart';
import 'package:plume_pdf/app/modules/home/models/pdf_reader_state.dart';

void main() {
  test('selection changes never mutate AI turn state', () {
    final HomeController controller = HomeController();
    final PdfAiSelection initialSelection = PdfAiSelection.area(
      pageNumber: 1,
      bounds: const PdfRect(10, 100, 120, 20),
    );
    const PdfAiPanelState runningTurn = PdfAiPanelState(
      apiKey: 'cached-key',
      loading: true,
      sessionId: 7,
      actionLabel: '解释',
      actionId: 42,
      actionSelectionText: 'old selection',
      result: 'partial answer',
      reasoning: 'partial reasoning',
      followUpSuggestions: <String>['follow up'],
    );
    controller.state = PdfReaderState(
      aiSelectionMode: true,
      aiSelection: initialSelection,
      aiPanelState: runningTurn,
    );

    controller.onAiSelectionChanged(null);

    expect(controller.state.aiSelection, isNull);
    expect(controller.state.aiPanelState, same(runningTurn));
    expect(controller.state.aiPanelState.loading, isTrue);
    expect(controller.state.aiPanelState.result, 'partial answer');
    expect(controller.state.aiPanelState.reasoning, 'partial reasoning');

    final PdfAiSelection nextSelection = PdfAiSelection.area(
      pageNumber: 2,
      bounds: const PdfRect(20, 180, 160, 40),
    );
    controller.onAiSelectionChanged(nextSelection);

    expect(controller.state.aiSelection, same(nextSelection));
    expect(controller.state.aiPanelState, same(runningTurn));

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

  test('leaving a document clears document-scoped AI presentation state', () {
    final HomeController controller = HomeController();
    controller.state = const PdfReaderState(
      filePath: '/tmp/current.pdf',
      aiSelectionMode: true,
      aiPanelState: PdfAiPanelState(
        apiKey: 'cached-key',
        loading: true,
        sessionId: 3,
        actionLabel: '深度理解',
        actionId: 9,
        result: 'old result',
        reasoning: 'old reasoning',
        followUpSuggestions: <String>['old follow up'],
      ),
    );

    controller.showRecentFiles();

    expect(controller.state.filePath, isNull);
    expect(controller.state.aiSelectionMode, isFalse);
    expect(controller.state.aiPanelState.apiKey, 'cached-key');
    expect(controller.state.aiPanelState.loading, isFalse);
    expect(controller.state.aiPanelState.actionId, isNull);
    expect(controller.state.aiPanelState.result, isNull);
    expect(controller.state.aiPanelState.reasoning, isNull);
    expect(controller.state.aiPanelState.followUpSuggestions, isEmpty);

    controller.onClose();
  });
}
