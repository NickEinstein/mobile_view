import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Bundled fonts (they render offline). Poppins is the default.
abstract final class AppFonts {
  static const poppins = 'Poppins';
  static const openSans = 'OpenSans';

  /// Adds the fonts' SIL Open Font License texts to the app's licence page,
  /// as the licence requires when the fonts are distributed.
  static void registerLicenses() {
    LicenseRegistry.addLicense(() async* {
      for (final (family, path) in [
        ('Poppins', 'assets/fonts/OFL-Poppins.txt'),
        ('Open Sans', 'assets/fonts/OFL-OpenSans.txt'),
      ]) {
        final text = await rootBundle.loadString(path);
        yield LicenseEntryWithLineBreaks([family], text);
      }
    });
  }
}
