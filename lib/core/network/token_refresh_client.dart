import 'package:dio/dio.dart';
import 'package:vital_reg_mobile/core/network/json.dart';
import 'package:vital_reg_mobile/core/session/auth_tokens.dart';

/// Exchanges a refresh token for new tokens.
///
/// Uses a bare [Dio] with no auth interceptor, so a failing refresh can never
/// recurse into another refresh.
class TokenRefreshClient {
  TokenRefreshClient(this._dio);

  final Dio _dio;

  static const path = '/auth/refresh';

  /// Returns null when the refresh token is rejected or the call fails.
  Future<AuthTokens?> refresh(String refreshToken) async {
    try {
      final response = await _dio.post<Object?>(
        path,
        data: {'refreshToken': refreshToken},
      );
      return AuthTokens.fromJson(response.data.asJsonMap());
    } on DioException {
      return null;
    } on FormatException {
      return null;
    }
  }
}
