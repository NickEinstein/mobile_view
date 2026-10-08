import 'package:get_it/get_it.dart';
import 'package:vital_reg_mobile/features/surrogacy_birth/data/surrogacy_birth_repository_impl.dart';
import 'package:vital_reg_mobile/features/surrogacy_birth/domain/surrogacy_birth_repository.dart';

void registerSurrogacyBirthModule(GetIt getIt) {
  getIt.registerLazySingleton<SurrogacyBirthRepository>(
    () => SurrogacyBirthRepositoryImpl(client: getIt(), storage: getIt()),
  );
}
