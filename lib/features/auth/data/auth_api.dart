import 'package:vital_reg_mobile/core/network/api_client.dart';
import 'package:vital_reg_mobile/core/network/json.dart';
import 'package:vital_reg_mobile/core/result/result.dart';
import 'package:vital_reg_mobile/features/auth/data/dtos/sign_in_dto.dart';

/// Remote data source for auth. One method per endpoint, with no logic.
class AuthApi {
  AuthApi(this._client);

  final ApiClient _client;

  /// [user] is an email, phone number or user name. [device] is this
  /// install's id: the backend allows each account one device.
  Future<Result<SignInDto>> login({
    required String user,
    required String password,
    required String device,
  }) => _client.post(
    '/auth/login',
    body: {'user': user, 'password': password, 'device': device},
    authenticated: false,
    decode: SignInDto.fromJson,
  );

  /// Only records the sign-out; the token stays valid until it expires.
  Future<Result<void>> logout({required String user}) =>
      _client.post('/auth/logout', body: {'user': user}, decode: (_) {});

  Future<Result<void>> requestPasswordReset({required String email}) =>
      _client.post(
        '/auth/password/forgot',
        body: {'email': email},
        authenticated: false,
        decode: (_) {},
      );

  Future<Result<String>> verifyPasswordResetCode({
    required String email,
    required String code,
  }) => _client.post(
    '/auth/password/verify-code',
    body: {'email': email, 'code': code},
    authenticated: false,
    decode: (json) => json.asJsonMap().requireString('resetToken'),
  );

  Future<Result<void>> resetPassword({
    required String resetToken,
    required String password,
  }) => _client.post(
    '/auth/password/reset',
    body: {'resetToken': resetToken, 'password': password},
    authenticated: false,
    decode: (_) {},
  );
}
