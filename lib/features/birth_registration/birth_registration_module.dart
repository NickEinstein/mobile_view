import 'package:get_it/get_it.dart';
import 'package:vital_reg_mobile/core/offline/pending_sends.dart';
import 'package:vital_reg_mobile/core/session/session_manager.dart';
import 'package:vital_reg_mobile/core/storage/user_storage.dart';
import 'package:vital_reg_mobile/features/birth_registration/data/birth_registration_repository_impl.dart';
import 'package:vital_reg_mobile/features/birth_registration/data/saved_places.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/birth_registration_repository.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/outbox_sync.dart';

void registerBirthRegistrationModule(GetIt getIt) {
  getIt
    ..registerLazySingleton<BirthRegistrationRepository>(
      () => BirthRegistrationRepositoryImpl(
        client: getIt(),
        storage: getIt(),
        savedPlaces: SavedPlaces(),
        offlineMode: getIt(),
      ),
    )
    ..registerLazySingleton<OutboxSync>(
      () => OutboxSync(
        getIt(),
        getIt(),
        isSignedIn: () =>
            getIt<SessionManager>().status == SessionStatus.authenticated &&
            getIt<UserStorage>().scope.userId != null,
      )..start(),
      dispose: (sync) => sync.dispose(),
    )
    ..registerLazySingleton<PendingSends>(() => getIt<OutboxSync>());
}
