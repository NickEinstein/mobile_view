abstract final class AppRoutes {
  static const splash = '/splash';
  static const onboarding = '/onboarding';
  static const login = '/login';
  static const forgotPassword = '/forgot-password';
  static const home = '/';

  // Bottom tab pages (home is the first; Services is a sheet).
  static const applications = '/applications';
  static const profile = '/profile';

  // Birth Registration (the module path must match AppModule).
  static const birthRegistration = '/registrations/birth';
  static const birthNinCheck = '$birthRegistration/new';
  static const birthForm = '$birthRegistration/form';
  static const birthPayment = '$birthRegistration/payment';
  static const birthQueriedPattern = '$birthRegistration/queried/:id';
  static String birthQueried(String id) =>
      '$birthRegistration/queried/${Uri.encodeComponent(id)}';
  static const birthApplicationPattern = '$birthRegistration/applications/:id';
  static String birthApplication(String id) =>
      '$birthRegistration/applications/${Uri.encodeComponent(id)}';

  // Birth Attestation (the module path must match AppModule).
  static const birthAttestation = '/registrations/birth-attestation';
  static const birthAttestationNew = '$birthAttestation/new';
  static const birthAttestationNin = '$birthAttestation/nin';
  static const birthAttestationFace = '$birthAttestation/face';
  static const birthAttestationForm = '$birthAttestation/form';
  static const birthAttestationApplicationPattern =
      '$birthAttestation/applications/:id';
  static String birthAttestationApplication(String id) =>
      '$birthAttestation/applications/${Uri.encodeComponent(id)}';
  static const birthAttestationQueriedPattern = '$birthAttestation/queried/:id';
  static String birthAttestationQueried(String id) =>
      '$birthAttestation/queried/${Uri.encodeComponent(id)}';

  // Modifications (the module path must match AppModule). `:kind` is a
  // ModificationKind name.
  static const modifications = '/records/modifications';
  static const modificationNewPattern = '$modifications/:kind/new';
  static String modificationNew(String kind) => '$modifications/$kind/new';
  static const modificationPaymentPattern = '$modifications/:kind/payment';
  static String modificationPayment(String kind) =>
      '$modifications/$kind/payment';
  static const modificationLookupPattern = '$modifications/:kind/record';
  static String modificationLookup(String kind) =>
      '$modifications/$kind/record';
  static const modificationFormPattern = '$modifications/:kind/form';
  static String modificationForm(String kind) => '$modifications/$kind/form';
  static const modificationQueriedPattern = '$modifications/:kind/queried/:id';
  static String modificationQueried(String kind, String id) =>
      '$modifications/$kind/queried/${Uri.encodeComponent(id)}';

  // Still Birth Registration (the module path must match AppModule).
  static const stillBirth = '/registrations/still-birth';
  static const stillBirthForm = '$stillBirth/form';
  static const stillBirthRegistrationPattern = '$stillBirth/registrations/:id';
  static String stillBirthRegistration(String id) =>
      '$stillBirth/registrations/${Uri.encodeComponent(id)}';

  // Death Registration (the module path must match AppModule).
  static const deathRegistration = '/registrations/death';
  static const deathForm = '$deathRegistration/form';

  // Surrogacy Birth Registration (the module path must match AppModule).
  static const surrogacyBirth = '/registrations/surrogacy-birth';
  static const surrogacyBirthNin = '$surrogacyBirth/nin';
  static const surrogacyBirthPayment = '$surrogacyBirth/payment';
  static const surrogacyBirthForm = '$surrogacyBirth/form';
  static const surrogacyBirthApplicationPattern =
      '$surrogacyBirth/applications/:id';
  static String surrogacyBirthApplication(String id) =>
      '$surrogacyBirth/applications/${Uri.encodeComponent(id)}';
  static const surrogacyBirthQueriedPattern = '$surrogacyBirth/queried/:id';
  static String surrogacyBirthQueried(String id) =>
      '$surrogacyBirth/queried/${Uri.encodeComponent(id)}';

  // Adopted Child Registration (the module path must match AppModule).
  static const adoptedChild = '/registrations/adopted-child';
  static const adoptedChildNin = '$adoptedChild/nin';
  static const adoptedChildPayment = '$adoptedChild/payment';
  static const adoptedChildForm = '$adoptedChild/form';
  static const adoptedChildApplicationPattern =
      '$adoptedChild/applications/:id';
  static String adoptedChildApplication(String id) =>
      '$adoptedChild/applications/${Uri.encodeComponent(id)}';
  static const adoptedChildQueriedPattern = '$adoptedChild/queried/:id';
  static String adoptedChildQueried(String id) =>
      '$adoptedChild/queried/${Uri.encodeComponent(id)}';

  // Foreign Birth Notification (the module path must match AppModule).
  static const foreignBirth = '/registrations/foreign-birth';
  static const foreignBirthPayment = '$foreignBirth/payment';
  static const foreignBirthForm = '$foreignBirth/form';
  static const foreignBirthApplicationPattern =
      '$foreignBirth/applications/:id';
  static String foreignBirthApplication(String id) =>
      '$foreignBirth/applications/${Uri.encodeComponent(id)}';
  static const foreignBirthQueriedPattern = '$foreignBirth/queried/:id';
  static String foreignBirthQueried(String id) =>
      '$foreignBirth/queried/${Uri.encodeComponent(id)}';
  static const deathRecordPattern = '$deathRegistration/records/:id';
  static String deathRecord(String id) =>
      '$deathRegistration/records/${Uri.encodeComponent(id)}';
  static const deathQueriedPattern = '$deathRegistration/queried/:id';
  static String deathQueried(String id) =>
      '$deathRegistration/queried/${Uri.encodeComponent(id)}';

  // Certificate Reissuance (the module path must match AppModule).
  static const reissuance = '/records/reissuance';
  static const reissuanceNew = '$reissuance/new';
  static const reissuanceValidate = '$reissuance/validate';
  static const reissuanceFace = '$reissuance/face';
  static const reissuanceCertificate = '$reissuance/certificate';
  static const reissuanceFormPattern = '$reissuance/form/:kind';
  static String reissuanceForm(String kind) => '$reissuance/form/$kind';
  // `:kind` is a ReissuanceKind name.
  static const reissuanceRequestPattern = '$reissuance/requests/:kind/:id';
  static String reissuanceRequest(String kind, String id) =>
      '$reissuance/requests/$kind/${Uri.encodeComponent(id)}';
  static const reissuanceUpdatePattern =
      '$reissuance/requests/:kind/:id/update';
  static String reissuanceUpdate(String kind, String id) =>
      '$reissuance/requests/$kind/${Uri.encodeComponent(id)}/update';

  /// Reachable without a session.
  static const publicRoutes = {splash, onboarding, login, forgotPassword};

  /// Where a signed-out user may be once onboarding is done.
  static const signedOutRoutes = {login, forgotPassword};
}
