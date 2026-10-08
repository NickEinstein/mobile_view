import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vital_reg_mobile/app/app.dart';
import 'package:vital_reg_mobile/app/app_bloc_observer.dart';
import 'package:vital_reg_mobile/app/di/injector.dart';
import 'package:vital_reg_mobile/core/config/app_config.dart';
import 'package:vital_reg_mobile/core/observability/crash_reporter.dart';
import 'package:vital_reg_mobile/design_system/icons/app_icons.dart';
import 'package:vital_reg_mobile/design_system/tokens/app_fonts.dart';

/// Entry point for every flavor: config, DI, error hooks, then the app.
/// Every uncaught error goes to [CrashReporter].
Future<void> bootstrap(Flavor flavor) async {
  WidgetsFlutterBinding.ensureInitialized();

  final config = AppConfig.fromEnvironment(flavor);
  await configureDependencies(config);

  final crashReporter = getIt<CrashReporter>();
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    unawaited(
      crashReporter.recordError(
        details.exception,
        details.stack ?? StackTrace.current,
        fatal: true,
      ),
    );
  };
  WidgetsBinding.instance.platformDispatcher.onError = (error, stackTrace) {
    unawaited(crashReporter.recordError(error, stackTrace, fatal: true));
    return true;
  };
  Bloc.observer = AppBlocObserver(crashReporter);
  AppFonts.registerLicenses();
  AppIcons.registerLicenses();

  runApp(const App());
}
