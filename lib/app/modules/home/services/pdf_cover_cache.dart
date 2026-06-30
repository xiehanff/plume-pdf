import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';

class PdfCoverCache {
  PdfCoverCache._();

  static final PdfCoverCache instance = PdfCoverCache._();

  static const String _coversDirName = 'pdf_covers';

  String? _coversDir;

  Future<String> _ensureCoversDir() async {
    if (_coversDir != null) {
      return _coversDir!;
    }
    final Directory supportDir = await getApplicationSupportDirectory();
    final String dir = path.join(supportDir.path, _coversDirName);
    await Directory(dir).create(recursive: true);
    _coversDir = dir;
    return dir;
  }

  String _coverFileName(String pdfPath) {
    final Digest digest = md5.convert(pdfPath.codeUnits);
    return '$digest.png';
  }

  Future<String?> getCoverPath(String pdfPath) async {
    final String dir = await _ensureCoversDir();
    final String coverPath = path.join(dir, _coverFileName(pdfPath));
    if (await File(coverPath).exists()) {
      return coverPath;
    }
    return null;
  }

  Future<String> generateCover(String pdfPath) async {
    final String dir = await _ensureCoversDir();
    final String coverPath = path.join(dir, _coverFileName(pdfPath));

    final PdfDocument doc = await PdfDocument.openFile(pdfPath);
    try {
      final PdfPage page = doc.pages.first;
      const double scale = 1.5;
      final PdfImage? rendered = await page.render(
        fullWidth: page.width * scale,
        fullHeight: page.height * scale,
      );
      if (rendered == null) {
        return '';
      }

      final ui.Image image = await rendered.createImage();
      rendered.dispose();
      final ByteData? data = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      image.dispose();
      if (data == null) {
        return '';
      }

      await File(coverPath).writeAsBytes(data.buffer.asUint8List());
      return coverPath;
    } finally {
      doc.dispose();
    }
  }

  Future<String> getOrGenerateCover(String pdfPath) async {
    final String? cached = await getCoverPath(pdfPath);
    if (cached != null) {
      return cached;
    }
    return generateCover(pdfPath);
  }
}
