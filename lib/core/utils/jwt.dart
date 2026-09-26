import 'dart:convert';

/// Reads JWT claims. It does NOT verify signatures; that is the server's job.
/// The app only uses `exp` to avoid restoring sessions it knows are dead.
abstract final class Jwt {
  static Map<String, Object?>? claims(String token) {
    final parts = token.split('.');
    if (parts.length != 3) return null;
    try {
      final payload = utf8.decode(
        base64Url.decode(base64Url.normalize(parts[1])),
      );
      final Object? decoded = jsonDecode(payload);
      return decoded is Map<String, Object?> ? decoded : null;
    } on FormatException {
      return null;
    }
  }

  /// Null when the token is opaque or has no `exp` claim.
  static DateTime? expiry(String token) {
    final exp = claims(token)?['exp'];
    return exp is int
        ? DateTime.fromMillisecondsSinceEpoch(exp * 1000, isUtc: true)
        : null;
  }

  /// Opaque tokens and tokens without `exp` are never treated as expired;
  /// the server stays the authority for those.
  static bool isExpired(
    String token, {
    DateTime? now,
    Duration leeway = const Duration(seconds: 30),
  }) {
    final expiresAt = expiry(token);
    if (expiresAt == null) return false;
    return (now ?? DateTime.now().toUtc()).isAfter(expiresAt.subtract(leeway));
  }
}
