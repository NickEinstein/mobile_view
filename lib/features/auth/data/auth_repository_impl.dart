import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:vital_reg_mobile/core/error/failure.dart';
import 'package:vital_reg_mobile/core/observability/crash_reporter.dart';
import 'package:vital_reg_mobile/core/result/result.dart';
import 'package:vital_reg_mobile/core/session/device_id.dart';
import 'package:vital_reg_mobile/core/session/session_manager.dart';
import 'package:vital_reg_mobile/core/storage/user_storage.dart';
import 'package:vital_reg_mobile/features/auth/data/auth_api.dart';
import 'package:vital_reg_mobile/features/auth/data/dtos/sign_in_dto.dart';
import 'package:vital_reg_mobile/features/auth/data/dtos/user_dto.dart';
import 'package:vital_reg_mobile/features/auth/domain/auth_repository.dart';
import 'package:vital_reg_mobile/features/auth/domain/entities/user.dart';
import 'package:vital_reg_mobile/features/auth/domain/value_objects/credentials.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required AuthApi api,
    required SessionManager sessionManager,
    required FlutterSecureStorage storage,
    required UserStorage userStorage,
    required DeviceId deviceId,
    required CrashReporter crashReporter,
  }) : _api = api,
       _deviceId = deviceId,
       _session = sessionManager,
       _storage = storage,
       _userStorage = userStorage,
       _crashReporter = crashReporter;

  final AuthApi _api;
  final SessionManager _session;
  final FlutterSecureStorage _storage;
  final UserStorage _userStorage;
  final DeviceId _deviceId;
  final CrashReporter _crashReporter;

  /// The signed-in user's profile. It is personal data, so it is kept in
  /// secure storage.
  static const _userCacheKey = 'current_user';

  /// Users this app doesn't serve (DCRs, directors, admins) are refused
  /// before a session starts; they use other portals.
  @override
  Future<Result<void>> signIn({
    required Email email,
    required Password password,
  }) async {
    final result = await _api.login(
      user: email.value.trim(),
      password: password.value,
      device: await _deviceId.read(),
    );
    switch (result) {
      case Ok(value: SignInDto(:final tokens, user: final user?)):
        // The backend has no "current user" endpoint: the profile comes
        // with sign-in and is kept for the session.
        await _storage.write(
          key: _userCacheKey,
          value: jsonEncode(user.toJson()),
        );
        await _session.start(tokens);
        return const Ok(null);
      case Ok():
        await _storage.delete(key: _userCacheKey);
        return const Err(ForbiddenFailure('Role not served by this app.'));
      case Err(:final failure):
        return Err(failure);
    }
  }

  /// The user who signed in, as the sign-in response described them. Without
  /// that copy the session can't continue, so the caller ends it.
  @override
  Future<Result<User>> currentUser() async {
    final dto = await _readCachedUser();
    if (dto == null) return const Err(UnauthorizedFailure());
    _userStorage.scope.enter(dto.id);
    await _crashReporter.setUser(dto.id);
    return Ok(dto.toDomain());
  }

  @override
  Future<void> signOut({required SessionEndReason reason}) async {
    final user = await _readCachedUser();
    if (reason != SessionEndReason.expired && user != null) {
      // Best effort, for the audit trail. The token stays valid until it
      // expires; the backend can't revoke it.
      await _api.logout(user: user.login);
    }
    // A deliberate sign-out removes this user's drafts (not payments);
    // expiry and inactivity keep them.
    if (reason == SessionEndReason.userInitiated) {
      await _userStorage.clearDrafts();
    }
    await _storage.delete(key: _userCacheKey);
    await _crashReporter.setUser(null);
    await _session.end(reason: reason);
  }

  Future<UserDto?> _readCachedUser() async {
    final raw = await _storage.read(key: _userCacheKey);
    if (raw == null) return null;
    try {
      final Object? json = jsonDecode(raw);
      return UserDto.fromJson(json);
    } on FormatException {
      return null;
    }
  }
}
