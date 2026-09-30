import 'package:vital_reg_mobile/core/network/json.dart';
import 'package:vital_reg_mobile/core/session/auth_tokens.dart';
import 'package:vital_reg_mobile/features/auth/data/dtos/user_dto.dart';

/// `POST /auth/login` → `{success, message, user, access_token}`.
final class SignInDto {
  const SignInDto({required this.tokens, required this.user});

  factory SignInDto.fromJson(Object? json) {
    final map = json.asJsonMap();
    return SignInDto(
      tokens: AuthTokens(accessToken: map.requireString('access_token')),
      user: UserDto.fromSignIn(map['user']),
    );
  }

  final AuthTokens tokens;

  /// Null when the account's role isn't one this app serves.
  final UserDto? user;
}
