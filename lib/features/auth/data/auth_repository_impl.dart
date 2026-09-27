import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:vital_reg_mobile/core/error/failure.dart';
import 'package:vital_reg_mobile/core/observability/crash_reporter.dart';
import 'package:vital_reg_mobile/core/result/result.dart';
import 'package:vital_reg_mobile/core/session/session_manager.dart';
import 'package:vital_reg_mobile/features/auth/data/auth_api.dart';
import 'package:vital_reg_mobile/features/auth/data/dtos/user_dto.dart';
import 'package:vital_reg_mobile/features/auth/domain/auth_repository.dart';
import 'package:vital_reg_mobile/features/auth/domain/entities/user.dart';
import 'package:vital_reg_mobile/features/auth/domain/value_objects/credentials.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required AuthApi api,
    required SessionManager sessionManager,
    required FlutterSecureStorage storage,
    required CrashReporter crashReporter,
  }) : _api = api,
       _session = sessionManager,
       _storage = storage,
       _crashReporter = crashReporter;

  final AuthApi _api;
  final SessionManager _session;
  final FlutterSecureStorage _storage;
  final CrashReporter _crashReporter;

  /// The profile is personal data, so it is cached in secure storage too.
  static const _userCacheKey = 'current_user';

  @override
  Future<Result<void>> signIn({
    required Email email,
    required Password password,
  }) async {
    final result = await _api.login(
      email: email.value.trim(),
      password: password.value,
    );
    switch (result) {
      case Ok(value: final tokens):
        await _storage.delete(key: _userCacheKey);
        await _session.start(tokens);
        return const Ok(null);
      case Err(:final failure):
        return Err(failure);
    }
  }

  @override
  Future<Result<User>> currentUser() async {
    final result = await _api.me();
    switch (result) {
      case Ok(value: final dto):
        await _storage.write(
          key: _userCacheKey,
          value: jsonEncode(dto.toJson()),
        );
        await _crashReporter.setUser(dto.id);
        return Ok(dto.toDomain());
      case Err(:final failure):
        if (failure is NetworkFailure || failure is TimeoutFailure) {
          final cached = await _readCachedUser();
          if (cached != null) return Ok(cached);
        }
        return Err(failure);
    }
  }

  @override
  Future<void> signOut({required SessionEndReason reason}) async {
    if (reason != SessionEndReason.expired) {
      await _api.logout();
    }
    await _storage.delete(key: _userCacheKey);
    await _crashReporter.setUser(null);
    await _session.end(reason: reason);
  }

  Future<User?> _readCachedUser() async {
    final raw = await _storage.read(key: _userCacheKey);
    if (raw == null) return null;
    try {
      final Object? json = jsonDecode(raw);
      return UserDto.fromJson(json).toDomain();
    } on FormatException {
      return null;
    }
  }
}
