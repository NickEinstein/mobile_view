import 'package:get_it/get_it.dart';
import 'package:vital_reg_mobile/features/modifications/data/modifications_repository_impl.dart';
import 'package:vital_reg_mobile/features/modifications/domain/modifications_repository.dart';

void registerModificationsModule(GetIt getIt) {
  getIt.registerLazySingleton<ModificationsRepository>(
    () => ModificationsRepositoryImpl(client: getIt(), storage: getIt()),
  );
}
