import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:vital_reg_mobile/core/session/auth_tokens.dart';
import 'package:vital_reg_mobile/core/session/token_storage.dart';
import 'package:vital_reg_mobile/core/session/user_scope.dart';
import 'package:vital_reg_mobile/core/storage/user_storage.dart';

class InMemoryTokenStorage implements TokenStorage {
  InMemoryTokenStorage([this._tokens]);

  AuthTokens? _tokens;

  @override
  Future<AuthTokens?> read() async => _tokens;

  @override
  Future<void> write(AuthTokens tokens) async {
    _tokens = tokens;
  }

  @override
  Future<void> clear() async {
    _tokens = null;
  }
}

/// Unsigned JWT with an `exp` claim, for expiry tests only.
String fakeJwt({required DateTime expiresAt}) {
  String encode(Map<String, Object?> json) =>
      base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
  final header = encode({'alg': 'none'});
  final payload = encode({'exp': expiresAt.millisecondsSinceEpoch ~/ 1000});
  return '$header.$payload.signature';
}

/// Secure storage for a signed-in test user. Pair it with
/// `FlutterSecureStorage.setMockInitialValues` where a test reads it back.
UserStorage signedInUserStorage({String userId = 'test-user'}) =>
    UserStorage(const FlutterSecureStorage(), UserScope()..enter(userId));
