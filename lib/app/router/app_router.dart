import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:vital_reg_mobile/app/router/app_module.dart';
import 'package:vital_reg_mobile/app/router/redirect.dart';
import 'package:vital_reg_mobile/app/router/routes.dart';
import 'package:vital_reg_mobile/app/view/app_shell.dart';
import 'package:vital_reg_mobile/app/view/home_tab.dart';
import 'package:vital_reg_mobile/app/view/module_placeholder_page.dart';
import 'package:vital_reg_mobile/app/view/splash_page.dart';
import 'package:vital_reg_mobile/app/view/tab_placeholder_page.dart';
import 'package:vital_reg_mobile/core/feature_flags/feature_flags.dart';
import 'package:vital_reg_mobile/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:vital_reg_mobile/features/auth/presentation/login/view/login_page.dart';
import 'package:vital_reg_mobile/features/auth/presentation/password_reset/view/password_reset_page.dart';
import 'package:vital_reg_mobile/features/onboarding/domain/onboarding_repository.dart';
import 'package:vital_reg_mobile/features/onboarding/presentation/view/onboarding_page.dart';

GoRouter createRouter({
  required AuthBloc authBloc,
  required FeatureFlags featureFlags,
  required OnboardingRepository onboarding,
  required Listenable refreshListenable,
}) {
  final rootNavigatorKey = GlobalKey<NavigatorState>();
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: AppRoutes.splash,
    refreshListenable: refreshListenable,
    redirect: (context, state) => resolveRedirect(
      auth: authBloc.state,
      location: state.uri,
      onboardingCompleted: onboarding.isCompleted,
    ),
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashPage(),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (context, state) => const OnboardingPage(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => LoginPage(
          onForgotPassword: () =>
              unawaited(context.push<void>(AppRoutes.forgotPassword)),
        ),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        builder: (context, state) =>
            PasswordResetPage(onExit: () => context.go(AppRoutes.login)),
      ),
      // Signed-in area: tab pages, each with its own history. (Services is
      // a sheet, not a page; see AppShell.)
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                builder: (context, state) => const HomeTab(),
                routes: [
                  // Modules open above the tabs, so Back returns home. A
                  // disabled module isn't routable.
                  for (final module in AppModule.values)
                    if (featureFlags.isEnabled(module.feature))
                      GoRoute(
                        parentNavigatorKey: rootNavigatorKey,
                        // Child paths are relative to '/'.
                        path: module.path.substring(1),
                        builder: (context, state) =>
                            ModulePlaceholderPage(module: module),
                      ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.applications,
                builder: (context, state) => const TabPlaceholderPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.profile,
                builder: (context, state) => const TabPlaceholderPage(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
