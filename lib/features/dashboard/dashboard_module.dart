import 'package:get_it/get_it.dart';
import 'package:vital_reg_mobile/features/dashboard/data/dashboard_repository_impl.dart';
import 'package:vital_reg_mobile/features/dashboard/domain/dashboard_repository.dart';

void registerDashboardModule(GetIt getIt) {
  getIt.registerLazySingleton<DashboardRepository>(
    () => DashboardRepositoryImpl(getIt()),
  );
}
