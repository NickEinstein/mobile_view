abstract final class AppRoutes {
  static const splash = '/splash';
  static const onboarding = '/onboarding';
  static const login = '/login';
  static const home = '/';

  /// Reachable without a session.
  static const publicRoutes = {splash, onboarding, login};
}
