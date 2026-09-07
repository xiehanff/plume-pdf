import 'dart:convert';

import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../theme/app_colors.dart';
import '../models/pdf_recent_file.dart';

class PdfReaderStore {
  static const String _recentFilesKey = 'pdf_reader_recent_files';
  static const String _backgroundThemeKey = 'pdf_reader_background_theme';
  static const int _maxRecentFiles = 50;

  Future<List<PdfRecentFile>> loadRecentFiles() async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    final List<String> rawItems =
        preferences.getStringList(_recentFilesKey) ?? const <String>[];

    return rawItems
        .map((String item) => _decodeRecentFile(item))
        .whereType<PdfRecentFile>()
        .toList()
      ..sort(
        (PdfRecentFile a, PdfRecentFile b) =>
            b.lastOpenedAt.compareTo(a.lastOpenedAt),
      );
  }

  Future<void> saveRecentFiles(List<PdfRecentFile> files) async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    final List<String> payload = files
        .take(_maxRecentFiles)
        .map((PdfRecentFile file) => jsonEncode(file.toJson()))
        .toList();
    await preferences.setStringList(_recentFilesKey, payload);
  }

  PdfRecentFile? findByPath(List<PdfRecentFile> files, String filePath) {
    for (final PdfRecentFile item in files) {
      if (item.path == filePath) {
        return item;
      }
    }
    return null;
  }

  Future<List<PdfRecentFile>> removeFile(
    List<PdfRecentFile> currentFiles,
    String filePath,
  ) async {
    final List<PdfRecentFile> nextFiles = currentFiles
        .where((PdfRecentFile item) => item.path != filePath)
        .toList();
    await saveRecentFiles(nextFiles);
    return nextFiles;
  }

  Future<List<PdfRecentFile>> rememberFile(
    List<PdfRecentFile> currentFiles,
    String filePath, {
    required int lastPage,
    String? coverPath,
  }) async {
    final PdfRecentFile? existing = findByPath(currentFiles, filePath);
    final List<PdfRecentFile> nextFiles = <PdfRecentFile>[
      PdfRecentFile(
        path: filePath,
        name: path.basename(filePath),
        lastOpenedAt: DateTime.now(),
        lastPage: lastPage,
        coverPath: coverPath ?? existing?.coverPath,
      ),
      ...currentFiles.where((PdfRecentFile item) => item.path != filePath),
    ];
    await saveRecentFiles(nextFiles);
    return nextFiles;
  }

  PdfRecentFile? _decodeRecentFile(String raw) {
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      return PdfRecentFile.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  Future<PdfBackgroundTheme> loadBackgroundTheme() async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    final String? raw = preferences.getString(_backgroundThemeKey);
    if (raw == null) {
      return PdfBackgroundTheme.normal;
    }
    try {
      return PdfBackgroundTheme.values.firstWhere((t) => t.name == raw);
    } catch (_) {
      return PdfBackgroundTheme.normal;
    }
  }

  Future<void> saveBackgroundTheme(PdfBackgroundTheme theme) async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    await preferences.setString(_backgroundThemeKey, theme.name);
  }
}
