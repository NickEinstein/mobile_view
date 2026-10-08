import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:vital_reg_mobile/core/network/json.dart';
import 'package:vital_reg_mobile/core/session/auth_tokens.dart';

abstract interface class TokenStorage {
  Future<AuthTokens?> read();
  Future<void> write(AuthTokens tokens);
  Future<void> clear();
}

/// Credentials live in the Keychain / Keystore only, never in plain-text
/// storage.
final class SecureTokenStorage implements TokenStorage {
  SecureTokenStorage(this._storage);

  final FlutterSecureStorage _storage;
  static const _key = 'auth_tokens';

  /// In-memory copy so the auth interceptor doesn't hit the keystore on
  /// every request.
  AuthTokens? _cache;

  @override
  Future<AuthTokens?> read() async {
    final cached = _cache;
    if (cached != null) return cached;

    final raw = await _storage.read(key: _key);
    if (raw == null) return null;
    try {
      final Object? decoded = jsonDecode(raw);
      return _cache = AuthTokens.fromJson(decoded.asJsonMap());
    } on FormatException {
      await clear();
      return null;
    }
  }

  @override
  Future<void> write(AuthTokens tokens) async {
    _cache = tokens;
    await _storage.write(key: _key, value: jsonEncode(tokens.toJson()));
  }

  @override
  Future<void> clear() async {
    _cache = null;
    await _storage.delete(key: _key);
  }
}
