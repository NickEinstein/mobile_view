import 'package:dio/dio.dart';

/// DEV FLAVOR ONLY. Answers the auth endpoints locally so the app can be
/// demoed without a backend. Enabled by `USE_FAKE_API=true` in
/// config/dev.json; `AppConfig` refuses it in staging and prod.
///
/// Demo behaviour:
/// - any email and password (8+ characters) signs in as a registrar;
/// - password reset always sends a code, and the code is `1234`.
class FakeBackendInterceptor extends Interceptor {
  /// [latency] is long enough by default to see loading states; tests
  /// pass zero.
  FakeBackendInterceptor({this.latency = const Duration(milliseconds: 700)});

  final Duration latency;

  static const demoCode = '1234';

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    final body = options.data;
    final fields = body is Map<String, Object?>
        ? body
        : const <String, Object?>{};

    final path = options.path;

    switch ((options.method, path)) {
      // As the backend answers: the profile comes with the token.
      case ('POST', '/auth/login'):
        _ok(handler, options, {
          'success': true,
          'message': 'Welcome',
          'user': {
            'User_ID': 1,
            'UserName': 'favour.allison',
            'Email': 'favour.allison@demo.test',
            'First_Name': 'Favour',
            'Last_Name': 'Allison',
            'Role_ID': 3,
            'Reg_Center_ID': 12,
          },
          'access_token': 'fake-access-token',
        });
      case ('POST', '/auth/logout' || '/auth/password/forgot'):
        _ok(handler, options, null);
      case ('POST', '/auth/password/verify-code'):
        if (fields['code'] == demoCode) {
          _ok(handler, options, {'resetToken': 'fake-reset-token'});
        } else {
          _fail(handler, options, 422, 'The code is incorrect or expired.');
        }
      case ('POST', '/auth/password/reset'):
        _ok(handler, options, null);
      case _:
        _fail(handler, options, 404, 'Not available in the demo backend.');
    }
  }

  void _ok(
    RequestInterceptorHandler handler,
    RequestOptions options,
    Object? data,
  ) => handler.resolve(
    Response<Object?>(requestOptions: options, statusCode: 200, data: data),
  );

  void _fail(
    RequestInterceptorHandler handler,
    RequestOptions options,
    int statusCode,
    String message,
  ) => handler.reject(
    DioException(
      requestOptions: options,
      type: DioExceptionType.badResponse,
      response: Response<Object?>(
        requestOptions: options,
        statusCode: statusCode,
        data: {'message': message},
      ),
    ),
  );
}
