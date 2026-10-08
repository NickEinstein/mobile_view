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
import 'package:vital_reg_mobile/features/adopted_child/domain/adopted_child_repository.dart';
import 'package:vital_reg_mobile/features/adopted_child/domain/entities/adoption_draft.dart';
import 'package:vital_reg_mobile/features/adopted_child/presentation/details/view/adoption_details_page.dart';
import 'package:vital_reg_mobile/features/adopted_child/presentation/form/view/adoption_form_page.dart';
import 'package:vital_reg_mobile/features/adopted_child/presentation/home/view/adopted_child_home_page.dart';
import 'package:vital_reg_mobile/features/adopted_child/presentation/nin/view/child_nin_page.dart'
    as adoption;
import 'package:vital_reg_mobile/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:vital_reg_mobile/features/auth/presentation/login/view/login_page.dart';
import 'package:vital_reg_mobile/features/auth/presentation/password_reset/view/password_reset_page.dart';
import 'package:vital_reg_mobile/features/birth_attestation/domain/birth_attestation_repository.dart';
import 'package:vital_reg_mobile/features/birth_attestation/presentation/details/view/attestation_details_page.dart';
import 'package:vital_reg_mobile/features/birth_attestation/presentation/face/view/face_validation_page.dart';
import 'package:vital_reg_mobile/features/birth_attestation/presentation/form/view/attestation_form_page.dart';
import 'package:vital_reg_mobile/features/birth_attestation/presentation/home/view/birth_attestation_home_page.dart';
import 'package:vital_reg_mobile/features/birth_attestation/presentation/nin/view/applicant_nin_page.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/birth_registration_repository.dart';
import 'package:vital_reg_mobile/features/birth_registration/presentation/details/view/application_details_page.dart';
import 'package:vital_reg_mobile/features/birth_registration/presentation/form/view/registration_form_page.dart';
import 'package:vital_reg_mobile/features/birth_registration/presentation/home/view/birth_registration_home_page.dart';
import 'package:vital_reg_mobile/features/birth_registration/presentation/nin_check/view/nin_check_page.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/domain/entities/reissuance_draft.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/domain/entities/reissuance_summary.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/domain/reissuance_repository.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/presentation/attestation_form/view/attestation_reissuance_form_page.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/presentation/birth_form/view/birth_reissuance_form_page.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/presentation/certificate/view/legacy_certificate_page.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/presentation/details/view/reissuance_details_page.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/presentation/home/view/reissuance_home_page.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/presentation/validation/view/nin_validation_page.dart';
import 'package:vital_reg_mobile/features/death_registration/presentation/details/view/death_details_page.dart';
import 'package:vital_reg_mobile/features/death_registration/presentation/form/view/death_form_page.dart';
import 'package:vital_reg_mobile/features/death_registration/presentation/home/view/death_registration_home_page.dart';
import 'package:vital_reg_mobile/features/foreign_birth/domain/entities/foreign_birth_draft.dart';
import 'package:vital_reg_mobile/features/foreign_birth/domain/foreign_birth_repository.dart';
import 'package:vital_reg_mobile/features/foreign_birth/presentation/details/view/foreign_birth_details_page.dart';
import 'package:vital_reg_mobile/features/foreign_birth/presentation/form/view/foreign_birth_form_page.dart';
import 'package:vital_reg_mobile/features/foreign_birth/presentation/home/view/foreign_birth_home_page.dart';
import 'package:vital_reg_mobile/features/modifications/domain/entities/modification_options.dart';
import 'package:vital_reg_mobile/features/modifications/domain/entities/modification_record.dart';
import 'package:vital_reg_mobile/features/modifications/domain/entities/modification_request.dart';
import 'package:vital_reg_mobile/features/modifications/domain/modifications_repository.dart';
import 'package:vital_reg_mobile/features/modifications/presentation/form/view/modification_form_page.dart';
import 'package:vital_reg_mobile/features/modifications/presentation/form/view/queried_modification_page.dart';
import 'package:vital_reg_mobile/features/modifications/presentation/home/view/modifications_home_page.dart';
import 'package:vital_reg_mobile/features/modifications/presentation/lookup/view/record_lookup_page.dart';
import 'package:vital_reg_mobile/features/modifications/presentation/request/view/modification_request_page.dart';
import 'package:vital_reg_mobile/features/onboarding/domain/onboarding_repository.dart';
import 'package:vital_reg_mobile/features/onboarding/presentation/view/onboarding_page.dart';
import 'package:vital_reg_mobile/features/payments/presentation/view/payment_page.dart';
import 'package:vital_reg_mobile/features/still_birth/presentation/details/view/still_birth_details_page.dart';
import 'package:vital_reg_mobile/features/still_birth/presentation/form/view/still_birth_form_page.dart';
import 'package:vital_reg_mobile/features/still_birth/presentation/home/view/still_birth_home_page.dart';
import 'package:vital_reg_mobile/features/surrogacy_birth/domain/entities/surrogacy_draft.dart';
import 'package:vital_reg_mobile/features/surrogacy_birth/domain/surrogacy_birth_repository.dart';
import 'package:vital_reg_mobile/features/surrogacy_birth/presentation/details/view/surrogacy_details_page.dart';
import 'package:vital_reg_mobile/features/surrogacy_birth/presentation/form/view/surrogacy_form_page.dart';
import 'package:vital_reg_mobile/features/surrogacy_birth/presentation/home/view/surrogacy_birth_home_page.dart';
import 'package:vital_reg_mobile/features/surrogacy_birth/presentation/nin/view/child_nin_page.dart';
import 'package:vital_reg_mobile/features/surrogacy_birth/presentation/payment/surrogacy_notice_dialog.dart';

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
                      else if (module == AppModule.birthAttestation)
                        _birthAttestationRoute(rootNavigatorKey)
                      else if (module == AppModule.modifications)
                        _modificationsRoute(rootNavigatorKey)
                      else if (module == AppModule.stillBirthRegistration)
                        _stillBirthRoute(rootNavigatorKey)
                      else if (module == AppModule.reissuance)
                        _reissuanceRoute(rootNavigatorKey)
                      else if (module == AppModule.deathRegistration)
                        _deathRoute(rootNavigatorKey)
                      else if (module == AppModule.surrogacyBirthRegistration)
                        _surrogacyBirthRoute(rootNavigatorKey)
                      else if (module == AppModule.adoptedChildRegistration)
                        _adoptedChildRoute(rootNavigatorKey)
                      else if (module == AppModule.foreignBirthNotification)
                        _foreignBirthRoute(rootNavigatorKey)
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

/// Birth Attestation: payment, the
/// applicant's NIN (or none), face, then the form.
GoRoute _birthAttestationRoute(GlobalKey<NavigatorState> rootNavigatorKey) {
  const home = AppRoutes.birthAttestation;
  GoRoute step(String path, GoRouterWidgetBuilder builder) => GoRoute(
    parentNavigatorKey: rootNavigatorKey,
    path: path.substring(home.length + 1),
    builder: builder,
  );

  return GoRoute(
    parentNavigatorKey: rootNavigatorKey,
    path: home.substring(1),
    builder: (context, state) => BirthAttestationHomePage(
      onStartApplication: () =>
          context.push<void>(AppRoutes.birthAttestationNew),
      onResumeAtFace: () => context.push<void>(AppRoutes.birthAttestationFace),
      onResumeAtForm: () => context.push<void>(AppRoutes.birthAttestationForm),
      onOpenApplication: (id) =>
          context.push<void>(AppRoutes.birthAttestationApplication(id)),
      onUpdateQueried: (id) =>
          context.push<void>(AppRoutes.birthAttestationQueried(id)),
    ),
    // Each step replaces the last, so Back returns to the home.
    routes: [
      step(
        AppRoutes.birthAttestationNew,
        (context, state) => PaymentPage(
          source: GetIt.instance<BirthAttestationRepository>().payments,
          onPaid: () => context.pushReplacement(AppRoutes.birthAttestationNin),
        ),
      ),
      step(
        AppRoutes.birthAttestationNin,
        (context, state) => ApplicantNinPage(
          onDone: () => context.pushReplacement(AppRoutes.birthAttestationFace),
        ),
      ),
      step(
        AppRoutes.birthAttestationFace,
        (context, state) => FaceValidationPage(
          onValidated: () =>
              context.pushReplacement(AppRoutes.birthAttestationForm),
        ),
      ),
      step(
        AppRoutes.birthAttestationForm,
        (context, state) => AttestationFormPage(onExit: () => context.pop()),
      ),
      step(
        AppRoutes.birthAttestationApplicationPattern,
        (context, state) => AttestationDetailsPage(
          id: state.pathParameters['id']!,
          // The correction replaces the details, so Back returns home.
          onUpdate: () => context.pushReplacement(
            AppRoutes.birthAttestationQueried(state.pathParameters['id']!),
          ),
        ),
      ),
      step(
        AppRoutes.birthAttestationQueriedPattern,
        (context, state) => AttestationFormPage(
          queriedRecordId: state.pathParameters['id'],
          onExit: () => context.pop(),
        ),
      ),
    ],
  );
}

/// Surrogacy Birth Registration: the server creates the application, then
/// the child's NIN, the payment and the form.
GoRoute _surrogacyBirthRoute(GlobalKey<NavigatorState> rootNavigatorKey) {
  const home = AppRoutes.surrogacyBirth;
  GoRoute step(String path, GoRouterWidgetBuilder builder) => GoRoute(
    parentNavigatorKey: rootNavigatorKey,
    path: path.substring(home.length + 1),
    builder: builder,
  );

  return GoRoute(
    parentNavigatorKey: rootNavigatorKey,
    path: home.substring(1),
    builder: (context, state) => SurrogacyBirthHomePage(
      onStart: () => context.push<void>(AppRoutes.surrogacyBirthNin),
      onResumeAt: (stage) => context.push<void>(switch (stage) {
        SurrogacyStage.nin => AppRoutes.surrogacyBirthNin,
        SurrogacyStage.payment => AppRoutes.surrogacyBirthPayment,
        SurrogacyStage.form => AppRoutes.surrogacyBirthForm,
      }),
      onOpenApplication: (id) =>
          context.push<void>(AppRoutes.surrogacyBirthApplication(id)),
    ),
    // Each step replaces the last, so Back returns to the home.
    routes: [
      step(
        AppRoutes.surrogacyBirthNin,
        (context, state) => ChildNinPage(
          onDone: () =>
              context.pushReplacement(AppRoutes.surrogacyBirthPayment),
        ),
      ),
      step(
        AppRoutes.surrogacyBirthPayment,
        (context, state) => PaymentPage(
          source: GetIt.instance<SurrogacyBirthRepository>().payments,
          onPaid: () async {
            await showSurrogacyNoticeDialog(context);
            if (context.mounted) {
              context.pushReplacement(AppRoutes.surrogacyBirthForm);
            }
          },
        ),
      ),
      step(
        AppRoutes.surrogacyBirthForm,
        (context, state) => SurrogacyFormPage(onExit: () => context.pop()),
      ),
      step(
        AppRoutes.surrogacyBirthApplicationPattern,
        (context, state) => SurrogacyDetailsPage(
          id: state.pathParameters['id']!,
          // The correction or the draft replaces the details, so Back
          // returns home.
          onRespondToQuery: () => context.pushReplacement(
            AppRoutes.surrogacyBirthQueried(state.pathParameters['id']!),
          ),
          onContinue: (stage) => context.pushReplacement(switch (stage) {
            SurrogacyStage.nin => AppRoutes.surrogacyBirthNin,
            SurrogacyStage.payment => AppRoutes.surrogacyBirthPayment,
            SurrogacyStage.form => AppRoutes.surrogacyBirthForm,
          }),
        ),
      ),
      step(
        AppRoutes.surrogacyBirthQueriedPattern,
        (context, state) => SurrogacyFormPage(
          queriedId: state.pathParameters['id'],
          onExit: () => context.pop(),
        ),
      ),
    ],
  );
}

/// Adopted Child Registration: the server creates the application, then
/// the child's NIN, the payment and the form.
GoRoute _adoptedChildRoute(GlobalKey<NavigatorState> rootNavigatorKey) {
  const home = AppRoutes.adoptedChild;
  String stagePath(AdoptionStage stage) => switch (stage) {
    AdoptionStage.nin => AppRoutes.adoptedChildNin,
    AdoptionStage.payment => AppRoutes.adoptedChildPayment,
    AdoptionStage.form => AppRoutes.adoptedChildForm,
  };
  GoRoute step(String path, GoRouterWidgetBuilder builder) => GoRoute(
    parentNavigatorKey: rootNavigatorKey,
    path: path.substring(home.length + 1),
    builder: builder,
  );

  return GoRoute(
    parentNavigatorKey: rootNavigatorKey,
    path: home.substring(1),
    builder: (context, state) => AdoptedChildHomePage(
      onStart: () => context.push<void>(AppRoutes.adoptedChildNin),
      onResumeAt: (stage) => context.push<void>(stagePath(stage)),
      onOpenApplication: (id) =>
          context.push<void>(AppRoutes.adoptedChildApplication(id)),
    ),
    // Each step replaces the last, so Back returns to the home.
    routes: [
      step(
        AppRoutes.adoptedChildNin,
        (context, state) => adoption.ChildNinPage(
          onDone: () => context.pushReplacement(AppRoutes.adoptedChildPayment),
        ),
      ),
      step(
        AppRoutes.adoptedChildPayment,
        (context, state) => PaymentPage(
          source: GetIt.instance<AdoptedChildRepository>().payments,
          onPaid: () => context.pushReplacement(AppRoutes.adoptedChildForm),
        ),
      ),
      step(
        AppRoutes.adoptedChildForm,
        (context, state) => AdoptionFormPage(onExit: () => context.pop()),
      ),
      step(
        AppRoutes.adoptedChildApplicationPattern,
        (context, state) => AdoptionDetailsPage(
          id: state.pathParameters['id']!,
          // The correction or the draft replaces the details, so Back
          // returns home.
          onRespondToQuery: () => context.pushReplacement(
            AppRoutes.adoptedChildQueried(state.pathParameters['id']!),
          ),
          onContinue: (stage) => context.pushReplacement(stagePath(stage)),
        ),
      ),
      step(
        AppRoutes.adoptedChildQueriedPattern,
        (context, state) => AdoptionFormPage(
          queriedId: state.pathParameters['id'],
          onExit: () => context.pop(),
        ),
      ),
    ],
  );
}

/// Foreign Birth Notification: the payment, then the form, submitted in
/// one go.
GoRoute _foreignBirthRoute(GlobalKey<NavigatorState> rootNavigatorKey) {
  const home = AppRoutes.foreignBirth;
  GoRoute step(String path, GoRouterWidgetBuilder builder) => GoRoute(
    parentNavigatorKey: rootNavigatorKey,
    path: path.substring(home.length + 1),
    builder: builder,
  );

  return GoRoute(
    parentNavigatorKey: rootNavigatorKey,
    path: home.substring(1),
    builder: (context, state) => ForeignBirthHomePage(
      onStart: () => context.push<void>(AppRoutes.foreignBirthPayment),
      onResumeAt: (stage) => context.push<void>(switch (stage) {
        ForeignBirthStage.payment => AppRoutes.foreignBirthPayment,
        ForeignBirthStage.form => AppRoutes.foreignBirthForm,
      }),
      onOpenApplication: (id) =>
          context.push<void>(AppRoutes.foreignBirthApplication(id)),
    ),
    // Each step replaces the last, so Back returns to the home.
    routes: [
      step(
        AppRoutes.foreignBirthPayment,
        (context, state) => PaymentPage(
          source: GetIt.instance<ForeignBirthRepository>().payments,
          onPaid: () => context.pushReplacement(AppRoutes.foreignBirthForm),
        ),
      ),
      step(
        AppRoutes.foreignBirthForm,
        (context, state) => ForeignBirthFormPage(onExit: () => context.pop()),
      ),
      step(
        AppRoutes.foreignBirthApplicationPattern,
        (context, state) => ForeignBirthDetailsPage(
          id: state.pathParameters['id']!,
          // The correction replaces the details, so Back returns home.
          onRespondToQuery: () => context.pushReplacement(
            AppRoutes.foreignBirthQueried(state.pathParameters['id']!),
          ),
        ),
      ),
      step(
        AppRoutes.foreignBirthQueriedPattern,
        (context, state) => ForeignBirthFormPage(
          queriedId: state.pathParameters['id'],
          onExit: () => context.pop(),
        ),
      ),
    ],
  );
}

/// Death Registration: home, the form, Certificate Details and the
/// correction of a queried record.
GoRoute _deathRoute(GlobalKey<NavigatorState> rootNavigatorKey) {
  const home = AppRoutes.deathRegistration;
  return GoRoute(
    parentNavigatorKey: rootNavigatorKey,
    path: home.substring(1),
    builder: (context, state) => DeathRegistrationHomePage(
      onOpenForm: () => context.push<void>(AppRoutes.deathForm),
      onOpenRegistration: (id) => context.push<void>(AppRoutes.deathRecord(id)),
      onUpdateQueried: (id) => context.push<void>(AppRoutes.deathQueried(id)),
    ),
    routes: [
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.deathForm.substring(home.length + 1),
        builder: (context, state) => DeathFormPage(onExit: () => context.pop()),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.deathRecordPattern.substring(home.length + 1),
        builder: (context, state) => DeathDetailsPage(
          id: state.pathParameters['id']!,
          // The correction replaces the details, so Back returns home.
          onUpdate: () => context.pushReplacement(
            AppRoutes.deathQueried(state.pathParameters['id']!),
          ),
        ),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.deathQueriedPattern.substring(home.length + 1),
        builder: (context, state) => DeathFormPage(
          queriedRecordId: state.pathParameters['id'],
          onExit: () => context.pop(),
        ),
      ),
    ],
  );
}

/// Still Birth Registration: home, the form and one registration's
/// details.
GoRoute _stillBirthRoute(GlobalKey<NavigatorState> rootNavigatorKey) {
  const home = AppRoutes.stillBirth;
  return GoRoute(
    parentNavigatorKey: rootNavigatorKey,
    path: home.substring(1),
    builder: (context, state) => StillBirthHomePage(
      onOpenForm: () => context.push<void>(AppRoutes.stillBirthForm),
      onOpenRegistration: (id) =>
          context.push<void>(AppRoutes.stillBirthRegistration(id)),
    ),
    routes: [
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.stillBirthForm.substring(home.length + 1),
        builder: (context, state) =>
            StillBirthFormPage(onExit: () => context.pop()),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.stillBirthRegistrationPattern.substring(
          home.length + 1,
        ),
        builder: (context, state) =>
            StillBirthDetailsPage(id: state.pathParameters['id']!),
      ),
    ],
  );
}

/// Certificate Reissuance: payment, the
/// applicant's NIN, face, the old certificate, then the form for its type.
GoRoute _reissuanceRoute(GlobalKey<NavigatorState> rootNavigatorKey) {
  const home = AppRoutes.reissuance;
  GoRoute step(String path, GoRouterWidgetBuilder builder) => GoRoute(
    parentNavigatorKey: rootNavigatorKey,
    path: path.substring(home.length + 1),
    builder: builder,
  );
  ReissuanceRepository repository() => GetIt.instance<ReissuanceRepository>();
  ReissuanceKind? kindOf(GoRouterState state) =>
      ReissuanceKind.values.asNameMap()[state.pathParameters['kind']];
  String? unknownKind(BuildContext context, GoRouterState state) =>
      kindOf(state) == null ? home : null;
  GoRoute kindStep(String path, GoRouterWidgetBuilder builder) => GoRoute(
    parentNavigatorKey: rootNavigatorKey,
    path: path.substring(home.length + 1),
    redirect: unknownKind,
    builder: builder,
  );

  return GoRoute(
    parentNavigatorKey: rootNavigatorKey,
    path: home.substring(1),
    builder: (context, state) => ReissuanceHomePage(
      onStart: () => context.push<void>(AppRoutes.reissuanceNew),
      onResume: (draft) => context.push<void>(switch (draft.nextStep) {
        ReissuanceStep.face => AppRoutes.reissuanceFace,
        ReissuanceStep.certificate => AppRoutes.reissuanceCertificate,
        ReissuanceStep.form => AppRoutes.reissuanceForm(
          draft.certificate!.kind.name,
        ),
      }),
      onOpenDetails: (kind, id) =>
          context.push<void>(AppRoutes.reissuanceRequest(kind.name, id)),
      onUpdate: (kind, id) =>
          context.push<void>(AppRoutes.reissuanceUpdate(kind.name, id)),
    ),
    // Each step replaces the last, so Back returns to the home.
    routes: [
      step(
        AppRoutes.reissuanceNew,
        (context, state) => PaymentPage(
          source: repository().payments,
          onPaid: () => context.pushReplacement(AppRoutes.reissuanceValidate),
        ),
      ),
      step(
        AppRoutes.reissuanceValidate,
        (context, state) => NinValidationPage(
          onDone: () => context.pushReplacement(AppRoutes.reissuanceFace),
        ),
      ),
      step(
        AppRoutes.reissuanceFace,
        (context, state) => FaceValidationPage(
          source: repository().face,
          onValidated: () =>
              context.pushReplacement(AppRoutes.reissuanceCertificate),
        ),
      ),
      step(
        AppRoutes.reissuanceCertificate,
        (context, state) => LegacyCertificatePage(
          onDone: (kind) =>
              context.pushReplacement(AppRoutes.reissuanceForm(kind.name)),
        ),
      ),
      kindStep(
        AppRoutes.reissuanceFormPattern,
        (context, state) => switch (kindOf(state)!) {
          ReissuanceKind.birth => BirthReissuanceFormPage(
            onExit: () => context.pop(),
          ),
          ReissuanceKind.attestation => AttestationReissuanceFormPage(
            onExit: () => context.pop(),
          ),
        },
      ),
      kindStep(AppRoutes.reissuanceRequestPattern, (context, state) {
        final kind = kindOf(state)!;
        final id = state.pathParameters['id']!;
        return ReissuanceDetailsPage(
          kind: kind,
          id: id,
          // The correction replaces the details, so Back returns home.
          onUpdate: () => context.pushReplacement(
            AppRoutes.reissuanceUpdate(kind.name, id),
          ),
        );
      }),
      kindStep(AppRoutes.reissuanceUpdatePattern, (context, state) {
        final id = state.pathParameters['id'];
        return switch (kindOf(state)!) {
          ReissuanceKind.birth => BirthReissuanceFormPage(
            queriedId: id,
            onExit: () => context.pop(),
          ),
          ReissuanceKind.attestation => AttestationReissuanceFormPage(
            queriedId: id,
            onExit: () => context.pop(),
          ),
        };
      }),
    ],
  );
}

/// Modifications: the request, its payment, the record lookup and the
/// form. Each step gets the earlier ones as `extra`; without it, home.
GoRoute _modificationsRoute(GlobalKey<NavigatorState> rootNavigatorKey) {
  const home = AppRoutes.modifications;
  ModificationKind? kindOf(GoRouterState state) =>
      ModificationKind.values.asNameMap()[state.pathParameters['kind']];
  String? unknownKind(BuildContext context, GoRouterState state) =>
      kindOf(state) == null ? home : null;
  String? needs<T>(BuildContext context, GoRouterState state) =>
      kindOf(state) == null || state.extra is! T ? home : null;

  // Named, so the flow can pop back to it (which also completes the
  // home's push and reloads its counts).
  const homeName = 'modifications';
  void backHome(BuildContext context) => Navigator.of(
    context,
  ).popUntil((route) => route.settings.name == homeName);

  return GoRoute(
    parentNavigatorKey: rootNavigatorKey,
    name: homeName,
    path: home.substring(1),
    builder: (context, state) => ModificationsHomePage(
      onNewRequest: (kind) =>
          context.push<void>(AppRoutes.modificationNew(kind.name)),
      onOpenQueried: (kind, id) =>
          context.push<void>(AppRoutes.modificationQueried(kind.name, id)),
    ),
    routes: [
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.modificationNewPattern.substring(home.length + 1),
        redirect: unknownKind,
        builder: (context, state) => ModificationRequestPage(
          kind: kindOf(state)!,
          onProceed: (request) => unawaited(
            context.push<void>(
              AppRoutes.modificationPayment(request.kind.name),
              extra: request,
            ),
          ),
        ),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.modificationPaymentPattern.substring(home.length + 1),
        redirect: needs<ModificationRequest>,
        // Paid: the lookup replaces this screen, so Back returns to the
        // request.
        builder: (context, state) {
          final request = state.extra! as ModificationRequest;
          return PaymentPage(
            source: GetIt.instance<ModificationsRepository>().payments(request),
            onPaid: () => context.pushReplacement(
              AppRoutes.modificationLookup(request.kind.name),
              extra: request,
            ),
          );
        },
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.modificationLookupPattern.substring(home.length + 1),
        redirect: needs<ModificationRequest>,
        builder: (context, state) {
          final request = state.extra! as ModificationRequest;
          return RecordLookupPage(
            kind: request.kind,
            onFound: (record) => unawaited(
              context.push<void>(
                AppRoutes.modificationForm(request.kind.name),
                extra: (request, record),
              ),
            ),
          );
        },
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.modificationFormPattern.substring(home.length + 1),
        redirect: needs<(ModificationRequest, ModificationRecord)>,
        // Done or exit: back to the home, which reloads.
        builder: (context, state) {
          final (request, record) =
              state.extra! as (ModificationRequest, ModificationRecord);
          return ModificationFormPage(
            request: request,
            record: record,
            onDone: () => backHome(context),
            onExit: () => backHome(context),
          );
        },
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.modificationQueriedPattern.substring(home.length + 1),
        redirect: unknownKind,
        builder: (context, state) => QueriedModificationPage(
          kind: kindOf(state)!,
          id: state.pathParameters['id']!,
          onDone: () => backHome(context),
        ),
      ),
    ],
  );
}
