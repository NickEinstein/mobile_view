import 'package:get_it/get_it.dart';
import 'package:vital_reg_mobile/core/config/app_config.dart';
import 'package:vital_reg_mobile/features/birth_attestation/data/face_verifier.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/data/reissuance_repository_impl.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/domain/reissuance_repository.dart';

void registerCertificateReissuanceModule(GetIt getIt) {
  getIt.registerLazySingleton<ReissuanceRepository>(
    () => ReissuanceRepositoryImpl(
      client: getIt(),
      storage: getIt(),
      faces: FaceVerifier(
        client: getIt(),
        url: getIt<AppConfig>().faceVerificationUrl,
      ),
    ),
  );
}
