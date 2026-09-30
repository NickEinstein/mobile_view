/// Keys for `RequestOptions.extra`, shared by `ApiClient` and interceptors.
abstract final class RequestFlags {
  /// Public endpoint (e.g. login): no Authorization header, and a 401 is
  /// an answer, not an expired session.
  static const skipAuth = 'skipAuth';
}
