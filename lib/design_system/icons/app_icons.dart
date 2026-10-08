import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Icons from the designs (Iconify SVGs, see `tool/fetch_icons.sh`).
enum AppIcons {
  menu('menu'),
  home('home'),
  services('services'),
  applications('applications'),
  profile('profile'),
  logOut('log_out'),
  birthRegistration('birth_registration'),
  birthAttestation('birth_attestation'),
  deathRegistration('death_registration'),
  stillBirth('still_birth'),
  user('user'),
  document('document'),
  heart('heart'),
  laurelWreath('laurel_wreath'),
  originHealth('origin_health'),
  childProgram('child_program'),
  parent('parent'),
  redo('redo');

  const AppIcons(this.file);

  /// File name in assets/icons, as listed in tool/fetch_icons.sh.
  final String file;

  String get asset => 'assets/icons/$file.svg';

  /// Credits required by the icon sets' licences (CC BY 4.0, MIT, Apache).
  static void registerLicenses() {
    LicenseRegistry.addLicense(() async* {
      final text = await rootBundle.loadString('assets/icons/LICENSES.txt');
      yield LicenseEntryWithLineBreaks(const ['Icons'], text);
    });
  }
}

/// Draws an [AppIcons] icon in one colour, like [Icon]. Takes its colour
/// and size from the surrounding [IconTheme] unless given.
class AppIcon extends StatelessWidget {
  const AppIcon(
    this.icon, {
    this.size,
    this.color,
    this.semanticLabel,
    super.key,
  });

  final AppIcons icon;
  final double? size;
  final Color? color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final theme = IconTheme.of(context);
    final size = this.size ?? theme.size ?? 24;
    final color = this.color ?? theme.color;
    return SvgPicture.asset(
      icon.asset,
      width: size,
      height: size,
      colorFilter: color == null
          ? null
          : ColorFilter.mode(color, BlendMode.srcIn),
      semanticsLabel: semanticLabel,
      excludeFromSemantics: semanticLabel == null,
    );
  }
}
