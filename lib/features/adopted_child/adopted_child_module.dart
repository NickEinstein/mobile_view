import 'package:get_it/get_it.dart';
import 'package:vital_reg_mobile/features/adopted_child/data/adopted_child_repository_impl.dart';
import 'package:vital_reg_mobile/features/adopted_child/domain/adopted_child_repository.dart';

void registerAdoptedChildModule(GetIt getIt) {
  getIt.registerLazySingleton<AdoptedChildRepository>(
    () => AdoptedChildRepositoryImpl(client: getIt(), storage: getIt()),
  );
}
