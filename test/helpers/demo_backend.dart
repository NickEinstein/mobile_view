import 'package:dio/dio.dart';
import 'package:vital_reg_mobile/app/dev/fake_backend_interceptor.dart';
import 'package:vital_reg_mobile/core/network/api_client.dart';
import 'package:vital_reg_mobile/core/observability/app_logger.dart';
import 'package:vital_reg_mobile/core/observability/crash_reporter.dart';
import 'package:vital_reg_mobile/core/result/result.dart';

/// A real [ApiClient] answered by the demo backend. [paths] records each
/// request as `METHOD /path`.
({ApiClient client, List<String> paths}) demoBackend() {
  final paths = <String>[];
  final dio = Dio(BaseOptions(baseUrl: 'https://demo.test'))
    ..interceptors.addAll([
      InterceptorsWrapper(
        onRequest: (options, handler) {
          paths.add('${options.method} ${options.path}');
          handler.next(options);
        },
      ),
      FakeBackendInterceptor(latency: Duration.zero),
    ]);
  return (
    client: ApiClient(dio, LoggingCrashReporter(AppLogger())),
    paths: paths,
  );
}

/// The value of an [Ok], failing the test with the failure otherwise.
T ok<T>(Result<T> result) => switch (result) {
  Ok(:final value) => value,
  Err(:final failure) => throw StateError('Expected Ok, got $failure'),
};
