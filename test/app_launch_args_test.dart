import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:plume_pdf/app/services/app_launch_args.dart';
import 'package:path/path.dart' as path;

void main() {
  test('firstPdfPath returns existing pdf argument', () async {
    final Directory tempDir = await Directory.systemTemp.createTemp(
      'plume_pdf_args_test_',
    );
    final File pdfFile = File(path.join(tempDir.path, 'sample.pdf'));
    await pdfFile.writeAsString('test');

    AppLaunchArgs.setArgs(<String>[
      '--trace-startup',
      pdfFile.path,
      'notes.txt',
    ]);

    expect(AppLaunchArgs.firstPdfPath(), pdfFile.path);

    await tempDir.delete(recursive: true);
  });
}
