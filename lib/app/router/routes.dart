abstract final class AppRoutes {
  static const splash = '/splash';
  static const onboarding = '/onboarding';
  static const login = '/login';
  static const forgotPassword = '/forgot-password';
  static const home = '/';

  // Bottom tab pages (home is the first; Services is a sheet).
  static const applications = '/applications';
  static const profile = '/profile';

  /// Reachable without a session.
  static const publicRoutes = {splash, onboarding, login, forgotPassword};

  /// Where a signed-out user may be once onboarding is done.
  static const signedOutRoutes = {login, forgotPassword};
}
