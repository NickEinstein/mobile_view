import 'package:equatable/equatable.dart';
import 'package:vital_reg_mobile/core/network/json.dart';

final class AuthTokens extends Equatable {
  const AuthTokens({required this.accessToken, required this.refreshToken});

  factory AuthTokens.fromJson(JsonMap json) => AuthTokens(
    accessToken: json.requireString('accessToken'),
    refreshToken: json.requireString('refreshToken'),
  );

  final String accessToken;
  final String refreshToken;

  JsonMap toJson() => {
    'accessToken': accessToken,
    'refreshToken': refreshToken,
  };

  @override
  List<Object?> get props => [accessToken, refreshToken];

  /// Tokens must never end up in logs or crash reports.
  @override
  String toString() => 'AuthTokens(<redacted>)';
}
