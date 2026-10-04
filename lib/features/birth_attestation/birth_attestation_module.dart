import 'package:get_it/get_it.dart';
import 'package:vital_reg_mobile/core/config/app_config.dart';
import 'package:vital_reg_mobile/features/birth_attestation/data/birth_attestation_repository_impl.dart';
import 'package:vital_reg_mobile/features/birth_attestation/data/face_verifier.dart';
import 'package:vital_reg_mobile/features/birth_attestation/domain/birth_attestation_repository.dart';

void registerBirthAttestationModule(GetIt getIt) {
  getIt.registerLazySingleton<BirthAttestationRepository>(
    () => BirthAttestationRepositoryImpl(
      client: getIt(),
      storage: getIt(),
      faces: FaceVerifier(
        client: getIt(),
        url: getIt<AppConfig>().faceVerificationUrl,
      ),
    ),
  );
}
