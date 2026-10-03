import 'package:get_it/get_it.dart';
import 'package:vital_reg_mobile/features/birth_registration/data/birth_registration_repository_impl.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/birth_registration_repository.dart';

void registerBirthRegistrationModule(GetIt getIt) {
  getIt.registerLazySingleton<BirthRegistrationRepository>(
    () => BirthRegistrationRepositoryImpl(client: getIt(), storage: getIt()),
  );
}
