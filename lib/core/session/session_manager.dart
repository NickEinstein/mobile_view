import 'dart:async';

import 'package:vital_reg_mobile/core/session/auth_tokens.dart';
import 'package:vital_reg_mobile/core/session/token_storage.dart';
import 'package:vital_reg_mobile/core/utils/jwt.dart';

enum SessionStatus { unknown, authenticated, unauthenticated }

enum SessionEndReason { userInitiated, expired, inactivity, invalid }

/// Single source of truth for the session. `AuthBloc` listens and the
/// router redirects from it; screens never navigate on login/logout.
class SessionManager {
  SessionManager(this._tokenStorage);

  final TokenStorage _tokenStorage;
  final StreamController<SessionStatus> _changes =
      StreamController<SessionStatus>.broadcast();

  SessionStatus _status = SessionStatus.unknown;
  SessionEndReason? _lastEndReason;

  SessionStatus get status => _status;

  /// Why the last session ended. The login screen uses it to explain
  /// ("You were signed out after a period of inactivity").
  SessionEndReason? get lastEndReason => _lastEndReason;

  Stream<SessionStatus> get changes => _changes.stream;

  /// Called once on app start.
  Future<void> restore() async {
    final tokens = await _tokenStorage.read();
    if (tokens == null) {
      _set(SessionStatus.unauthenticated);
      return;
    }
    if (Jwt.isExpired(tokens.accessToken)) {
      await end(reason: SessionEndReason.expired);
      return;
    }
    _set(SessionStatus.authenticated);
  }

  Future<void> start(AuthTokens tokens) async {
    await _tokenStorage.write(tokens);
    _lastEndReason = null;
    _set(SessionStatus.authenticated);
  }

  /// Idempotent. Parallel 401s or a double logout tap end the session once.
  Future<void> end({required SessionEndReason reason}) async {
    await _tokenStorage.clear();
    if (_status == SessionStatus.unauthenticated) return;
    _lastEndReason = reason;
    _set(SessionStatus.unauthenticated);
  }

  void _set(SessionStatus status) {
    if (_status == status) return;
    _status = status;
    _changes.add(status);
  }

  Future<void> dispose() => _changes.close();
}
