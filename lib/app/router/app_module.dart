import 'package:vital_reg_mobile/core/feature_flags/feature_flags.dart';
import 'package:vital_reg_mobile/features/auth/domain/entities/permission.dart';
import 'package:vital_reg_mobile/l10n/gen/app_localizations.dart';

/// The single access table: path + feature flag + required permission.
///
/// The router enforces it before a screen builds. Screens never re-check
/// roles, so no page renders or calls the API before access is checked,
/// and no route is left unguarded.
enum AppModule {
  birthRegistration(
    '/registrations/birth',
    Feature.birthRegistration,
    Permission.registerBirth,
  ),
  deathRegistration(
    '/registrations/death',
    Feature.deathRegistration,
    Permission.registerDeath,
  ),
  approvals('/approvals', Feature.approvals, Permission.approveRecords),
  reports('/reports', Feature.reports, Permission.viewReports);

  const AppModule(this.path, this.feature, this.permission);

  final String path;
  final Feature feature;
  final Permission permission;

  /// Matches the module root and any sub-route beneath it.
  static AppModule? fromPath(String path) {
    for (final module in values) {
      if (path == module.path || path.startsWith('${module.path}/')) {
        return module;
      }
    }
    return null;
  }

  String title(AppLocalizations l10n) => switch (this) {
    AppModule.birthRegistration => l10n.moduleBirthRegistration,
    AppModule.deathRegistration => l10n.moduleDeathRegistration,
    AppModule.approvals => l10n.moduleApprovals,
    AppModule.reports => l10n.moduleReports,
  };
}
