import 'package:vital_reg_mobile/core/network/api_client.dart';
import 'package:vital_reg_mobile/core/network/json.dart';
import 'package:vital_reg_mobile/core/result/result.dart';
import 'package:vital_reg_mobile/core/session/auth_tokens.dart';
import 'package:vital_reg_mobile/features/auth/data/dtos/user_dto.dart';

/// Remote data source for auth. One method per endpoint, with no logic.
class AuthApi {
  AuthApi(this._client);

  final ApiClient _client;

  Future<Result<AuthTokens>> login({
    required String email,
    required String password,
  }) => _client.post(
    '/auth/login',
    body: {'email': email, 'password': password},
    authenticated: false,
    decode: (json) => AuthTokens.fromJson(json.asJsonMap()),
  );

  Future<Result<UserDto>> me() =>
      _client.get('/auth/me', decode: UserDto.fromJson);

  Future<Result<void>> logout() => _client.post('/auth/logout', decode: (_) {});
}
