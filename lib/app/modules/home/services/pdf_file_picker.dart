import 'package:file_selector/file_selector.dart';

class PdfFilePicker {
  static const XTypeGroup _pdfTypeGroup = XTypeGroup(
    label: 'PDF',
    extensions: <String>['pdf'],
  );

  Future<String?> pickPdfFile() async {
    final XFile? file = await openFile(
      acceptedTypeGroups: const <XTypeGroup>[_pdfTypeGroup],
    );
    return file?.path;
  }
}
