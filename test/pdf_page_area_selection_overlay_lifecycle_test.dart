import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:plume_pdf/app/modules/home/models/pdf_ai_selection.dart';
import 'package:plume_pdf/app/modules/home/services/deepseek_service.dart';
import 'package:plume_pdf/app/modules/home/views/widgets/pdf_page_area_selection_overlay.dart';

void main() {
  testWidgets(
    'viewport update does not emit redundant selection clear during build',
    (WidgetTester tester) async {
      final GlobalKey<_OverlayHostState> hostKey =
          GlobalKey<_OverlayHostState>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _OverlayHost(key: hostKey),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(hostKey.currentState!.selectionChangeCount, 0);

      hostKey.currentState!.resize(const Size(640, 480));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(hostKey.currentState!.selectionChangeCount, 0);
    },
  );
}

class _OverlayHost extends StatefulWidget {
  const _OverlayHost({super.key});

  @override
  State<_OverlayHost> createState() => _OverlayHostState();
}

class _OverlayHostState extends State<_OverlayHost> {
  final PdfViewerController controller = PdfViewerController();
  Size viewportSize = const Size(600, 420);
  int selectionChangeCount = 0;

  void resize(Size size) {
    setState(() {
      viewportSize = size;
    });
  }

  void _onSelectionChanged(PdfAiSelection? selection) {
    selectionChangeCount++;
    // Mirrors HomeController/GetBuilder behavior: the old overlay implementation
    // invoked this from didUpdateWidget(), which made this setState illegal.
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: viewportSize.width,
      height: viewportSize.height,
      child: Stack(
        children: <Widget>[
          PdfViewerAreaSelectionOverlay(
            controller: controller,
            viewportSize: viewportSize,
            onSelectionChanged: _onSelectionChanged,
            onActionSelected: (AiToolAction action) {},
          ),
        ],
      ),
    );
  }
}
