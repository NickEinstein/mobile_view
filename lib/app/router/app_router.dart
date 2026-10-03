import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';
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
import 'package:vital_reg_mobile/features/birth_registration/domain/birth_registration_repository.dart';
import 'package:vital_reg_mobile/features/birth_registration/presentation/details/view/application_details_page.dart';
import 'package:vital_reg_mobile/features/birth_registration/presentation/form/view/registration_form_page.dart';
import 'package:vital_reg_mobile/features/birth_registration/presentation/home/view/birth_registration_home_page.dart';
import 'package:vital_reg_mobile/features/birth_registration/presentation/nin_check/view/nin_check_page.dart';
import 'package:vital_reg_mobile/features/onboarding/domain/onboarding_repository.dart';
import 'package:vital_reg_mobile/features/onboarding/presentation/view/onboarding_page.dart';
import 'package:vital_reg_mobile/features/payments/presentation/view/payment_page.dart';

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
                      if (module == AppModule.birthRegistration)
                        _birthRegistrationRoute(rootNavigatorKey)
                      else
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

/// Birth Registration: home, "New Birth Registration" (NIN check), form
/// (with the fee's payment from age 5), and one application's details.
GoRoute _birthRegistrationRoute(GlobalKey<NavigatorState> rootNavigatorKey) {
  const home = AppRoutes.birthRegistration;
  return GoRoute(
    parentNavigatorKey: rootNavigatorKey,
    path: home.substring(1),
    builder: (context, state) => BirthRegistrationHomePage(
      onStartApplication: () => context.push<void>(AppRoutes.birthNinCheck),
      onResumeApplication: () => context.push<void>(AppRoutes.birthForm),
      onOpenApplication: (id) =>
          context.push<void>(AppRoutes.birthApplication(id)),
    ),
    routes: [
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.birthNinCheck.substring(home.length + 1),
        // The form replaces this screen, so Back from the form returns
        // to the Birth Registration home.
        builder: (context, state) => NinCheckPage(
          onDone: () => context.pushReplacement(AppRoutes.birthForm),
        ),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.birthForm.substring(home.length + 1),
        builder: (context, state) => RegistrationFormPage(
          onExit: () => context.pop(),
          onPayment: () => context.push<void>(AppRoutes.birthPayment),
        ),
      ),
      // The fee for a child of 5 or older, over the form; closing it
      // returns there.
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.birthPayment.substring(home.length + 1),
        builder: (context, state) => PaymentPage(
          source: GetIt.instance<BirthRegistrationRepository>().payments,
          onPaid: () => context.pop(),
        ),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.birthApplicationPattern.substring(home.length + 1),
        builder: (context, state) =>
            ApplicationDetailsPage(id: state.pathParameters['id']!),
      ),
    ],
  );
}
