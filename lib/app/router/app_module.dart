import 'package:vital_reg_mobile/core/feature_flags/feature_flags.dart';
import 'package:vital_reg_mobile/features/auth/domain/entities/permission.dart';
import 'package:vital_reg_mobile/l10n/gen/app_localizations.dart';

/// The access table: path, feature flag and required permission, enforced
/// by the router before a screen builds.
enum AppModule {
  birthRegistration(
    '/registrations/birth',
    Feature.birthRegistration,
    Permission.registerBirth,
  ),
  birthAttestation(
    '/registrations/birth-attestation',
    Feature.birthAttestation,
    Permission.registerBirth,
  ),
  modifications(
    '/records/modifications',
    Feature.modifications,
    Permission.modifyRecords,
  ),
  stillBirthRegistration(
    '/registrations/still-birth',
    Feature.stillBirthRegistration,
    Permission.registerBirth,
  ),
  deathRegistration(
    '/registrations/death',
    Feature.deathRegistration,
    Permission.registerDeath,
  ),
  surrogacyBirthRegistration(
    '/registrations/surrogacy-birth',
    Feature.surrogacyBirthRegistration,
    Permission.registerBirth,
  ),
  adoptedChildRegistration(
    '/registrations/adopted-child',
    Feature.adoptedChildRegistration,
    Permission.registerBirth,
  ),
  singleParentBirthRegistration(
    '/registrations/single-parent-birth',
    Feature.singleParentBirthRegistration,
    Permission.registerBirth,
  ),
  foreignBirthNotification(
    '/registrations/foreign-birth',
    Feature.foreignBirthNotification,
    Permission.registerBirth,
  ),
  reissuance(
    '/records/reissuance',
    Feature.reissuance,
    Permission.reissueCertificates,
  ),
  approvals('/approvals', Feature.approvals, Permission.approveRecords),
  reports('/reports', Feature.reports, Permission.viewReports);

  const AppModule(this.path, this.feature, this.permission);

  final String path;
  final Feature feature;
  final Permission permission;

  /// The "New registration" sheet (Services), in the designed order.
  static const newRegistration = [
    birthRegistration,
    birthAttestation,
    modifications,
    stillBirthRegistration,
    deathRegistration,
    surrogacyBirthRegistration,
    adoptedChildRegistration,
    singleParentBirthRegistration,
    foreignBirthNotification,
    reissuance,
  ];

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
    AppModule.birthAttestation => l10n.moduleBirthAttestation,
    AppModule.modifications => l10n.moduleModifications,
    AppModule.stillBirthRegistration => l10n.moduleStillBirthRegistration,
    AppModule.deathRegistration => l10n.moduleDeathRegistration,
    AppModule.surrogacyBirthRegistration =>
      l10n.moduleSurrogacyBirthRegistration,
    AppModule.adoptedChildRegistration => l10n.moduleAdoptedChildRegistration,
    AppModule.singleParentBirthRegistration =>
      l10n.moduleSingleParentBirthRegistration,
    AppModule.foreignBirthNotification => l10n.moduleForeignBirthNotification,
    AppModule.reissuance => l10n.moduleReissuance,
    AppModule.approvals => l10n.moduleApprovals,
    AppModule.reports => l10n.moduleReports,
  };

  /// One-line description in the "New registration" sheet.
  String subtitle(AppLocalizations l10n) => switch (this) {
    AppModule.birthRegistration => l10n.moduleBirthRegistrationHint,
    AppModule.birthAttestation => l10n.moduleBirthAttestationHint,
    AppModule.modifications => l10n.moduleModificationsHint,
    AppModule.stillBirthRegistration => l10n.moduleStillBirthRegistrationHint,
    AppModule.deathRegistration => l10n.moduleDeathRegistrationHint,
    AppModule.surrogacyBirthRegistration =>
      l10n.moduleSurrogacyBirthRegistrationHint,
    AppModule.adoptedChildRegistration =>
      l10n.moduleAdoptedChildRegistrationHint,
    AppModule.singleParentBirthRegistration =>
      l10n.moduleSingleParentBirthRegistrationHint,
    AppModule.foreignBirthNotification =>
      l10n.moduleForeignBirthNotificationHint,
    AppModule.reissuance => l10n.moduleReissuanceHint,
    AppModule.approvals || AppModule.reports => '',
  };
}
