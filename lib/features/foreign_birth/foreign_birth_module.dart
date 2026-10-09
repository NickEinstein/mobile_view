import 'package:get_it/get_it.dart';
import 'package:vital_reg_mobile/features/foreign_birth/data/foreign_birth_repository_impl.dart';
import 'package:vital_reg_mobile/features/foreign_birth/domain/foreign_birth_repository.dart';

void registerForeignBirthModule(GetIt getIt) {
  getIt.registerLazySingleton<ForeignBirthRepository>(
    () => ForeignBirthRepositoryImpl(client: getIt(), storage: getIt()),
  );
}
