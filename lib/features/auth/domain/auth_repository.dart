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

  /// The signed-in user, from the sign-in response (the backend has no
  /// endpoint for it). Fails when there is none, and the session ends.
  Future<Result<User>> currentUser();

  Future<void> signOut({required SessionEndReason reason});
}
