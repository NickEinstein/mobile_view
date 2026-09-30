import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vital_reg_mobile/app/dev/fake_backend_interceptor.dart';
import 'package:vital_reg_mobile/core/config/app_config.dart';
import 'package:vital_reg_mobile/core/feature_flags/feature_flags.dart';
import 'package:vital_reg_mobile/core/network/api_client.dart';
import 'package:vital_reg_mobile/core/network/dio_factory.dart';
import 'package:vital_reg_mobile/core/observability/app_logger.dart';
import 'package:vital_reg_mobile/core/observability/crash_reporter.dart';
import 'package:vital_reg_mobile/core/observability/sentry_crash_reporter.dart';
import 'package:vital_reg_mobile/core/session/device_id.dart';
import 'package:vital_reg_mobile/core/session/session_manager.dart';
import 'package:vital_reg_mobile/core/session/token_storage.dart';
import 'package:vital_reg_mobile/core/session/user_scope.dart';
import 'package:vital_reg_mobile/core/storage/user_storage.dart';
import 'package:vital_reg_mobile/features/auth/auth_module.dart';
import 'package:vital_reg_mobile/features/onboarding/onboarding_module.dart';

final GetIt getIt = GetIt.instance;

/// Composition root: the ONLY place that picks concrete implementations.
/// Widgets never build repositories themselves.
Future<void> configureDependencies(AppConfig config) async {
  final logger = AppLogger();
  final CrashReporter crashReporter = config.sentryDsn.isEmpty
      ? LoggingCrashReporter(logger)
      : await SentryCrashReporter.init(
          dsn: config.sentryDsn,
          environment: config.flavor.name,
        );

  const secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  final preferences = await SharedPreferences.getInstance();
  final TokenStorage tokenStorage = SecureTokenStorage(secureStorage);
  final sessionManager = SessionManager(tokenStorage);
  final dio = createDio(
    config: config,
    tokenStorage: tokenStorage,
    sessionManager: sessionManager,
    logger: logger,
  );
  if (config.useFakeApi) {
    dio.interceptors.insert(0, FakeBackendInterceptor());
  }

  getIt
    ..registerSingleton<AppConfig>(config)
    ..registerSingleton<AppLogger>(logger)
    ..registerSingleton<CrashReporter>(crashReporter)
    ..registerSingleton<FeatureFlags>(
      StaticFeatureFlags(config.enabledFeatures),
    )
    ..registerSingleton<FlutterSecureStorage>(secureStorage)
    // Drafts and payment references, per user (registrars share devices).
    ..registerSingleton<UserStorage>(UserStorage(secureStorage, UserScope()))
    // Never cleared: the backend allows each account one device.
    ..registerSingleton<DeviceId>(
      DeviceId(secureStorage, override: config.deviceIdOverride),
    )
    ..registerSingleton<SharedPreferences>(preferences)
    ..registerSingleton<TokenStorage>(tokenStorage)
    ..registerSingleton<SessionManager>(
      sessionManager,
      dispose: (session) => session.dispose(),
    )
    ..registerSingleton<ApiClient>(ApiClient(dio, crashReporter));

  // One line per feature module.
  registerAuthModule(getIt);
  registerOnboardingModule(getIt);
}
