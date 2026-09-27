/// Keys for `RequestOptions.extra`, shared by `ApiClient` and interceptors.
abstract final class RequestFlags {
  /// Public endpoint (login, refresh): no Authorization header, no refresh.
  static const skipAuth = 'skipAuth';

  /// Set on the single retry after a token refresh, to prevent loops.
  static const retried = 'retried';
}
