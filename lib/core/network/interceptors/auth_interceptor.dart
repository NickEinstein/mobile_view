import 'package:dio/dio.dart';
import 'package:vital_reg_mobile/core/network/request_flags.dart';
import 'package:vital_reg_mobile/core/session/token_storage.dart';

/// Attaches the access token. A 401 (expired or revoked; there is no
/// refresh) ends the session via [onSessionExpired].
class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required TokenStorage tokenStorage,
    required Future<void> Function() onSessionExpired,
  }) : _tokenStorage = tokenStorage,
       _onSessionExpired = onSessionExpired;

  final TokenStorage _tokenStorage;
  final Future<void> Function() _onSessionExpired;

  static const _header = 'Authorization';

  static String _bearer(String token) => 'Bearer $token';

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (options.extra[RequestFlags.skipAuth] != true) {
      final tokens = await _tokenStorage.read();
      if (tokens != null) {
        options.headers[_header] = _bearer(tokens.accessToken);
      }
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final request = err.requestOptions;
    if (err.response?.statusCode == 401 &&
        request.extra[RequestFlags.skipAuth] != true) {
      final current = await _tokenStorage.read();
      // A late 401 for a token that was already replaced (the user signed
      // in again meanwhile) must not end the new session.
      final sentWithCurrentToken =
          current != null &&
          request.headers[_header] == _bearer(current.accessToken);
      if (current == null || sentWithCurrentToken) await _onSessionExpired();
    }
    handler.next(err);
  }
}
