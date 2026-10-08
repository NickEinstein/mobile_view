import 'package:get_it/get_it.dart';
import 'package:vital_reg_mobile/features/death_registration/data/death_registration_repository_impl.dart';
import 'package:vital_reg_mobile/features/death_registration/domain/death_registration_repository.dart';

void registerDeathRegistrationModule(GetIt getIt) {
  getIt.registerLazySingleton<DeathRegistrationRepository>(
    () => DeathRegistrationRepositoryImpl(client: getIt(), storage: getIt()),
  );
}
