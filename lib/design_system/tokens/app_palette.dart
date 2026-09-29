import 'package:flutter/material.dart';

/// The ONLY place for colour literals (`make check-colors` enforces it).
abstract final class AppPalette {
  /// UI green: buttons, headings, links, focused fields.
  static const brand = Color(0xFF028E38);

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

  /// Card outline, and the selected card on the dashboard.
  static const cardBorder = Color(0xFFE5E5E5);
  static const selectedCardFill = Color(0xFFE8F2EA);
  static const selectedCardBorder = Color(0xFF82BA8E);

  /// Small pill behind the user's role ("Registrar").
  static const chipFill = Color(0xFFE4F3EA);

  /// Dashboard stat icons.
  static const accentBlue = Color(0xFF007AFF);
  static const accentGreen = Color(0xFF028E38);
  static const accentYellow = Color(0xFFECC917);

  // "New registration" icons (from the designer's icon files).
  static const accentPurple = Color(0xFF8A38F5);
  static const accentTeal = Color(0xFF16C896);
  static const accentRed = Color(0xFFE94F4A);
  static const accentPlum = Color(0xFF704660);

  /// Destructive actions (Log Out) and the unread-notification dot.
  static const danger = Color(0xFFFF3B30);

  static const warningContainer = Color(0xFFFFF3E0);
  static const onWarningContainer = Color(0xFF5D4037);
}
