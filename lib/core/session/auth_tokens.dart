import 'package:equatable/equatable.dart';
import 'package:vital_reg_mobile/core/network/json.dart';

/// The bearer token from sign-in (about a day; no refresh token).
final class AuthTokens extends Equatable {
  const AuthTokens({required this.accessToken});

  /// The format kept in secure storage.
  factory AuthTokens.fromJson(JsonMap json) =>
      AuthTokens(accessToken: json.requireString('accessToken'));

  final String accessToken;

  JsonMap toJson() => {'accessToken': accessToken};

  @override
  List<Object?> get props => [accessToken];

  /// Tokens must never end up in logs or crash reports.
  @override
  String toString() => 'AuthTokens(<redacted>)';
}
