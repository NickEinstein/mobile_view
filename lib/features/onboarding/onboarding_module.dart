import 'package:get_it/get_it.dart';
import 'package:vital_reg_mobile/features/onboarding/data/onboarding_repository_impl.dart';
import 'package:vital_reg_mobile/features/onboarding/domain/onboarding_repository.dart';

/// Requires `SharedPreferences` to be registered first.
void registerOnboardingModule(GetIt getIt) {
  final repository = OnboardingRepositoryImpl(getIt());
  getIt.registerSingleton<OnboardingRepository>(
    repository,
    dispose: (_) => repository.dispose(),
  );
}
