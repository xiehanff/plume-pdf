import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plume_pdf/app/modules/home/views/widgets/chat_input_bar.dart';

void main() {
  testWidgets('输入框提示文字从左上角开始布局', (WidgetTester tester) async {
    final TextEditingController controller = TextEditingController();
    final FocusNode focusNode = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatInputBar(
            controller: controller,
            focusNode: focusNode,
            isLoading: false,
            onSend: (_) async {},
            onNewSession: () {},
            onSettingsTap: () {},
          ),
        ),
      ),
    );

    final TextField textField = tester.widget<TextField>(
      find.byType(TextField),
    );
    expect(textField.textAlignVertical, TextAlignVertical.top);
  });

  testWidgets('流式输出时发送按钮切换为停止并保持可点击', (
    WidgetTester tester,
  ) async {
    final TextEditingController controller = TextEditingController();
    final FocusNode focusNode = FocusNode();
    int stopCount = 0;
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatInputBar(
            controller: controller,
            focusNode: focusNode,
            isLoading: true,
            onSend: (_) async {},
            onStop: () {
              stopCount++;
            },
            onNewSession: () {},
            onSettingsTap: () {},
          ),
        ),
      ),
    );

    expect(find.byTooltip('停止生成'), findsOneWidget);
    expect(find.byIcon(Icons.stop_rounded), findsOneWidget);

    await tester.tap(find.byTooltip('停止生成'));
    await tester.pump();

    expect(stopCount, 1);
  });
}
