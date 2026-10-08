import 'package:flutter/widgets.dart';
import 'package:vital_reg_mobile/l10n/gen/app_localizations.dart';

export 'package:vital_reg_mobile/l10n/gen/app_localizations.dart';

extension AppLocalizationsX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
