import 'dart:io';

import 'package:flutter/services.dart';

class MacosFileOpenService {
  static const MethodChannel _channel = MethodChannel('plume_pdf/file_open');

  Future<void> bindOpenHandler(
    Future<void> Function(List<String>) onOpenFiles,
  ) async {
    if (!Platform.isMacOS) {
      return;
    }
    _channel.setMethodCallHandler((MethodCall call) async {
      if (call.method != 'openFiles') {
        return;
      }
      final List<Object?>? rawPaths = call.arguments as List<Object?>?;
      if (rawPaths == null || rawPaths.isEmpty) {
        return;
      }
      final List<String> filePaths = rawPaths.whereType<String>().toList();
      if (filePaths.isEmpty) {
        return;
      }
      await onOpenFiles(filePaths);
    });
    await _channel.invokeMethod<void>('flutterReady');
  }
}
