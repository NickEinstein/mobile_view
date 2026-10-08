import 'package:vital_reg_mobile/app/router/app_module.dart';
import 'package:vital_reg_mobile/app/router/routes.dart';
import 'package:vital_reg_mobile/features/auth/presentation/bloc/auth_bloc.dart';

/// Every navigation rule, as one pure (unit-tested) function. Returns where
/// to redirect, or null to allow navigation.
String? resolveRedirect({
  required AuthState auth,
  required Uri location,
  required bool onboardingCompleted,
}) {
  final path = location.path;
  final isPublic = AppRoutes.publicRoutes.contains(path);

  switch (auth) {
    case AuthUnknown():
      return path == AppRoutes.splash
          ? null
          : _withReturnPath(AppRoutes.splash, location);

    case AuthUnauthenticated():
      final target = onboardingCompleted
          ? AppRoutes.login
          : AppRoutes.onboarding;
      return path == target ? null : _withReturnPath(target, location);

    case AuthAuthenticated(:final user):
      if (isPublic) {
        return _safeReturnPath(location.queryParameters['from']) ??
            AppRoutes.home;
      }
      final module = AppModule.fromPath(path);
      if (module != null && !user.can(module.permission)) {
        return AppRoutes.home;
      }
      return null;
  }
}

/// Keeps the deep link the user was heading to, carrying it across
/// splash → login → destination.
String _withReturnPath(String target, Uri location) {
  final destination = AppRoutes.publicRoutes.contains(location.path)
      ? location.queryParameters['from']
      : location.toString();
  if (destination == null || destination.isEmpty) return target;
  return Uri(path: target, queryParameters: {'from': destination}).toString();
}

/// Only internal paths are allowed, so `?from=//evil.com` can't redirect
/// the user off the app.
String? _safeReturnPath(String? from) =>
    from != null && from.startsWith('/') && !from.startsWith('//')
    ? from
    : null;
