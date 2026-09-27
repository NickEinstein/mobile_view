import 'package:get_it/get_it.dart';
import 'package:vital_reg_mobile/features/auth/data/auth_api.dart';
import 'package:vital_reg_mobile/features/auth/data/auth_repository_impl.dart';
import 'package:vital_reg_mobile/features/auth/domain/auth_repository.dart';

/// Each feature registers its own dependencies. The composition root calls
/// this; nothing else in the feature touches `GetIt`.
void registerAuthModule(GetIt getIt) {
  getIt
    ..registerLazySingleton<AuthApi>(() => AuthApi(getIt()))
    ..registerLazySingleton<AuthRepository>(
      () => AuthRepositoryImpl(
        api: getIt(),
        sessionManager: getIt(),
        storage: getIt(),
        crashReporter: getIt(),
      ),
    );
}
