import 'package:vital_reg_mobile/core/result/result.dart';
import 'package:vital_reg_mobile/core/session/session_manager.dart';
import 'package:vital_reg_mobile/features/auth/domain/entities/user.dart';
import 'package:vital_reg_mobile/features/auth/domain/value_objects/credentials.dart';

abstract interface class AuthRepository {
  /// On success the session starts, and navigation follows automatically
  /// through `AuthBloc` and the router.
  Future<Result<void>> signIn({
    required Email email,
    required Password password,
  });

  /// Falls back to the last known profile when offline.
  Future<Result<User>> currentUser();

  Future<void> signOut({required SessionEndReason reason});
}
