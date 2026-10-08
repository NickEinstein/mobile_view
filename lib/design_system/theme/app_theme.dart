import 'package:flutter/material.dart';
import 'package:vital_reg_mobile/design_system/tokens/app_fonts.dart';
import 'package:vital_reg_mobile/design_system/tokens/app_palette.dart';

abstract final class AppTheme {
  /// Seeded from the brand green, with `primary` pinned to the exact brand
  /// value so buttons match the designs.
  static ThemeData light() => _build(
    ColorScheme.fromSeed(
      seedColor: AppPalette.brand,
    ).copyWith(primary: AppPalette.brand, onPrimary: Colors.white),
  );

  static ThemeData dark() => _build(
    ColorScheme.fromSeed(
      seedColor: AppPalette.brand,
      brightness: Brightness.dark,
    ),
  );

  static ThemeData _build(ColorScheme scheme) {
    final isLight = scheme.brightness == Brightness.light;
    OutlineInputBorder border(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: color),
    );

    return ThemeData(
      colorScheme: scheme,
      fontFamily: AppFonts.poppins,
      // Filled grey fields; the outline appears when focused (or filled, see
      // AppTextField).
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isLight
            ? AppPalette.fieldFill
            : scheme.surfaceContainerHighest,
        hintStyle: const TextStyle(color: AppPalette.muted),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 14,
        ),
        border: border(Colors.transparent),
        enabledBorder: border(Colors.transparent),
        focusedBorder: border(scheme.primary),
        errorBorder: border(scheme.error),
        focusedErrorBorder: border(scheme.error),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          // 52dp keeps tap targets above the 48dp accessibility minimum.
          minimumSize: const Size.fromHeight(52),
          shape: const StadiumBorder(),
          // Button text styles don't inherit ThemeData.fontFamily.
          textStyle: const TextStyle(
            fontFamily: AppFonts.poppins,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
          disabledBackgroundColor: isLight ? AppPalette.muted : null,
          disabledForegroundColor: isLight ? Colors.white : null,
        ),
      ),
    );
  }
}
