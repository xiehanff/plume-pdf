import 'dart:io';

import 'package:path/path.dart' as path;

class AppLaunchArgs {
  AppLaunchArgs._();

  static List<String> _args = const <String>[];

  static void setArgs(List<String> args) {
    _args = List<String>.unmodifiable(args);
  }

  static String? firstPdfPath() {
    for (final String argument in _args) {
      if (!_isExistingPdfFile(argument)) {
        continue;
      }
      return argument;
    }
    return null;
  }

  static bool _isExistingPdfFile(String filePath) {
    if (path.extension(filePath).toLowerCase() != '.pdf') {
      return false;
    }
    return File(filePath).existsSync();
  }
}
