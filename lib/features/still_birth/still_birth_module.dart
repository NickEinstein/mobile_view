import 'package:get_it/get_it.dart';
import 'package:vital_reg_mobile/features/still_birth/data/still_birth_repository_impl.dart';
import 'package:vital_reg_mobile/features/still_birth/domain/still_birth_repository.dart';

void registerStillBirthModule(GetIt getIt) {
  getIt.registerLazySingleton<StillBirthRepository>(
    () => StillBirthRepositoryImpl(client: getIt(), storage: getIt()),
  );
}
