import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:vital_reg_mobile/app/di/injector.dart';
import 'package:vital_reg_mobile/app/router/app_router.dart';
import 'package:vital_reg_mobile/app/router/stream_listenable.dart';
import 'package:vital_reg_mobile/app/session_timeout_scope.dart';
import 'package:vital_reg_mobile/core/config/app_config.dart';
import 'package:vital_reg_mobile/design_system/theme/app_theme.dart';
import 'package:vital_reg_mobile/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:vital_reg_mobile/features/onboarding/domain/onboarding_repository.dart';
import 'package:vital_reg_mobile/l10n/l10n.dart';

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  late final AuthBloc _authBloc;
  late final StreamListenable _authChanges;
  late final StreamListenable _onboardingChanges;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    final onboarding = getIt<OnboardingRepository>();
    _authBloc = AuthBloc(sessionManager: getIt(), repository: getIt())
      ..add(const AuthStarted());
    _authChanges = StreamListenable(_authBloc.stream);
    _onboardingChanges = StreamListenable(onboarding.changes);
    _router = createRouter(
      authBloc: _authBloc,
      featureFlags: getIt(),
      onboarding: onboarding,
      refreshListenable: Listenable.merge([_authChanges, _onboardingChanges]),
    );
  }

  @override
  void dispose() {
    _router.dispose();
    _authChanges.dispose();
    _onboardingChanges.dispose();
    unawaited(_authBloc.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _authBloc,
      child: MaterialApp.router(
        onGenerateTitle: (context) => context.l10n.appTitle,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: _router,
        builder: (context, child) => SessionTimeoutScope(
          timeout: getIt<AppConfig>().sessionTimeout,
          child: child ?? const SizedBox.shrink(),
        ),
      ),
    );
  }
}
