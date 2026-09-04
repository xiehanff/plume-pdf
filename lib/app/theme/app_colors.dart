import 'package:flutter/material.dart';

enum PdfBackgroundTheme { normal, night, parchment, green }

extension PdfBackgroundThemeX on PdfBackgroundTheme {
  ColorFilter? get colorFilter {
    switch (this) {
      case PdfBackgroundTheme.normal:
        return null;
      case PdfBackgroundTheme.night:
        return const ColorFilter.matrix(<double>[
          0.55,
          0,
          0,
          0,
          0,
          0,
          0.55,
          0,
          0,
          0,
          0,
          0,
          0.55,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
        ]);
      case PdfBackgroundTheme.parchment:
        return const ColorFilter.matrix(<double>[
          1.0,
          0,
          0,
          0,
          0,
          0,
          0.95,
          0,
          0,
          0,
          0,
          0,
          0.78,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
        ]);
      case PdfBackgroundTheme.green:
        return const ColorFilter.matrix(<double>[
          0.78,
          0,
          0,
          0,
          0,
          0,
          0.95,
          0,
          0,
          0,
          0,
          0,
          0.75,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
        ]);
    }
  }

  String get label {
    switch (this) {
      case PdfBackgroundTheme.normal:
        return '默认';
      case PdfBackgroundTheme.night:
        return '阴天';
      case PdfBackgroundTheme.parchment:
        return '羊皮纸';
      case PdfBackgroundTheme.green:
        return '护眼绿';
    }
  }
}

class AppColors {
  AppColors._();

  // ── Backgrounds ──
  /// Also used for the native title bar (sync with win32_window.cpp & MainFlutterWindow.swift).
  static const scaffoldBg = Color(0xFF262A37);
  static const surfaceBg = Color(0xFF343643);
  static const accentSurface = Color(0xFF5B5F6B);

  // ── Accent / Seed ──
  static const seed = Color(0xFF686687);
  static const accentBright = Color(0xFFB39DDB);
  static const aiBadgeBg = Color(0xE64A1D7D);

  // ── Selection ──
  static const selectionStroke = Color(0xFF3A6EA5);
  static const selectionFill = Color(0x1A7EC0EE);

  // ── Text ──
  static const textPrimary = Colors.white;
  static const textSecondary = Colors.white70;
  static const textTertiary = Colors.white54;
  static const textHint = Colors.white38;

  // ── Borders ──
  static const borderSubtle = Color(0x0DFFFFFF); // white @5%, = fillSubtle
  static const borderSoft = Color(0x14FFFFFF); // white @8%, = fillSoft
  static const borderVisible = Color(0x29FFFFFF); // white @16%
  static const borderFocused = Color(0xFFB39DDB); // = accentBright

  // ── Fills (button/container backgrounds) ──
  static const fillFaint = Color(0x08FFFFFF); // white @3%
  static const fillSubtle = Color(0x0DFFFFFF); // white @5%
  static const fillSoft = Color(0x14FFFFFF); // white @8%

  // ── Overlays / Masks ──
  static const loadingOverlay = Color(0x6632343E); // scaffoldBg @40%
  static const tooltipBg = Color(0xB2000000); // black @70%
  static const toolbarOverlayBg = Color(0xD9000000); // black @85%
  static const cardShadow = Color(0x66000000); // black @40%

  // ── Functional ──
  static const errorSoft = Color(0xFFFFB4B4);
  static const pageNavBg = Colors.black;
  static const transparent = Colors.transparent;
  static const fieldBg = Color(0x2E000000); // black @18%
}
