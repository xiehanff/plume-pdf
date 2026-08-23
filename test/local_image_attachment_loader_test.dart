import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:plume_pdf/app/modules/home/models/ai_chat_input.dart';
import 'package:plume_pdf/app/modules/home/services/local_image_attachment_loader.dart';

void main() {
  late Directory tempDirectory;
  late File imageFile;
  late File tiffFile;

  setUp(() {
    tempDirectory = Directory.systemTemp.createTempSync(
      'plume_pdf_image_loader_',
    );
    imageFile = File('${tempDirectory.path}${Platform.pathSeparator}局部截取.png')
      ..writeAsBytesSync(<int>[0x89, 0x50, 0x4E, 0x47]);
    tiffFile = File('${tempDirectory.path}${Platform.pathSeparator}局部截取.tiff')
      ..writeAsBytesSync(<int>[0x49, 0x49, 0x2A, 0x00]);
  });

  tearDown(() {
    tempDirectory.deleteSync(recursive: true);
  });

  test('清理剪贴板控制字符和引号后读取图片路径', () async {
    final AiImageAttachment? attachment = await LocalImageAttachmentLoader.load(
      '\u202A"${imageFile.path}"\u202C',
    );

    expect(attachment, isNotNull);
    expect(attachment!.sourcePath, imageFile.path);
    expect(attachment.mimeType, 'image/png');
    expect(attachment.bytes, <int>[0x89, 0x50, 0x4E, 0x47]);
  });

  test('支持 file URI 形式的图片路径', () async {
    final String fileUri = Uri.file(
      imageFile.path,
      windows: Platform.isWindows,
    ).toString();

    final AiImageAttachment? attachment = await LocalImageAttachmentLoader.load(
      fileUri,
    );

    expect(attachment, isNotNull);
    expect(attachment!.sourcePath, imageFile.path);
  });

  test('支持 TIFF 图片路径并保留正确 MIME 类型', () async {
    final AiImageAttachment? attachment = await LocalImageAttachmentLoader.load(
      tiffFile.path,
    );

    expect(attachment, isNotNull);
    expect(attachment!.mimeType, 'image/tiff');
  });
}
