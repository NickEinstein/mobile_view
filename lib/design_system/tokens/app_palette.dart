import 'package:flutter/material.dart';

/// The ONLY place for colour literals (`make check-colors` enforces it).
abstract final class AppPalette {
  /// UI green: buttons, headings, links, focused fields.
  static const brand = Color(0xFF008E37);

  /// Logo greens and gold (splash, illustrations).
  static const logoGreen = Color(0xFF058E46);
  static const logoGreenDark = Color(0xFF05783D);
  static const leaf = Color(0xFF6EBC45);
  static const gold = Color(0xFFC59833);

  /// Headings and field labels.
  static const inkStrong = Color(0xFF1E1E1E);

  /// Body text and the "VITALREG" wordmark.
  static const ink = Color(0xFF414141);

  /// Subtitles, hints, and the disabled button.
  static const muted = Color(0xFF9C9C9C);

  /// Text field background.
  static const fieldFill = Color(0xFFF3F4F2);

  static const warningContainer = Color(0xFFFFF3E0);
  static const onWarningContainer = Color(0xFF5D4037);
}
