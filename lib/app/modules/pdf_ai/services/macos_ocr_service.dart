import 'dart:io';

import 'package:flutter/services.dart';

class MacosOcrService {
  static const MethodChannel _channel = MethodChannel('plume_pdf/ocr');

  Future<String> recognizeText(Uint8List imageBytes) async {
    if ((!(Platform.isMacOS || Platform.isWindows)) || imageBytes.isEmpty) {
      return '';
    }
    final String? result = await _channel.invokeMethod<String>(
      'recognizeTextFromImage',
      <String, Object>{
        'imageBytes': imageBytes,
      },
    );
    return result?.trim() ?? '';
  }
}
