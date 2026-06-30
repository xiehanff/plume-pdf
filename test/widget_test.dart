// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:plume_pdf/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('首次启动显示空态', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.text('打开本地 PDF'), findsOneWidget);
    expect(find.text('选择 PDF 文件'), findsOneWidget);
  });
}
