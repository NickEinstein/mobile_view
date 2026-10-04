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

  /// Reachable without a session.
  static const publicRoutes = {splash, onboarding, login, forgotPassword};

  /// Where a signed-out user may be once onboarding is done.
  static const signedOutRoutes = {login, forgotPassword};
}
