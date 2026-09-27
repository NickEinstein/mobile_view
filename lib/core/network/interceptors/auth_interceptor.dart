import 'package:dio/dio.dart';
import 'package:vital_reg_mobile/core/network/request_flags.dart';
import 'package:vital_reg_mobile/core/session/auth_tokens.dart';
import 'package:vital_reg_mobile/core/session/token_storage.dart';

typedef TokenRefresher = Future<AuthTokens?> Function(String refreshToken);

/// Attaches the access token and transparently refreshes it on 401.
///
/// Because this is a [QueuedInterceptor], N parallel 401s trigger exactly
/// one refresh, and the rest retry with the new token. If the refresh fails,
/// [onSessionExpired] ends the session for the whole app; the router then
/// redirects to login. Screens do nothing.
class AuthInterceptor extends QueuedInterceptor {
  AuthInterceptor({
    required Dio dio,
    required TokenStorage tokenStorage,
    required TokenRefresher refresh,
    required Future<void> Function() onSessionExpired,
  }) : _dio = dio,
       _tokenStorage = tokenStorage,
       _refresh = refresh,
       _onSessionExpired = onSessionExpired;

  final Dio _dio;
  final TokenStorage _tokenStorage;
  final TokenRefresher _refresh;
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
    final shouldRefresh =
        err.response?.statusCode == 401 &&
        request.extra[RequestFlags.skipAuth] != true &&
        request.extra[RequestFlags.retried] != true;
    if (!shouldRefresh) {
      handler.next(err);
      return;
    }

    final current = await _tokenStorage.read();
    if (current == null) {
      await _onSessionExpired();
      handler.next(err);
      return;
    }

    var accessToken = current.accessToken;
    final sentWithCurrentToken =
        request.headers[_header] == _bearer(current.accessToken);
    if (sentWithCurrentToken) {
      final refreshed = await _refresh(current.refreshToken);
      if (refreshed == null) {
        await _onSessionExpired();
        handler.next(err);
        return;
      }
      await _tokenStorage.write(refreshed);
      accessToken = refreshed.accessToken;
    }

    try {
      final response = await _dio.fetch<Object?>(
        request
          ..headers[_header] = _bearer(accessToken)
          ..extra[RequestFlags.retried] = true,
      );
      handler.resolve(response);
    } on DioException catch (retryError) {
      handler.next(retryError);
    }
  }
}
