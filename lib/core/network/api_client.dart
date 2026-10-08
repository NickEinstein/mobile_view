import 'package:dio/dio.dart';
import 'package:vital_reg_mobile/core/error/failure.dart';
import 'package:vital_reg_mobile/core/network/error_mapper.dart';
import 'package:vital_reg_mobile/core/network/request_flags.dart';
import 'package:vital_reg_mobile/core/observability/crash_reporter.dart';
import 'package:vital_reg_mobile/core/result/result.dart';

typedef Decoder<T> = T Function(Object? json);

/// The only class that talks to Dio: every call decodes to a typed
/// [Result]. Used by repositories only.
class ApiClient {
  ApiClient(this._dio, this._crashReporter);

  final Dio _dio;
  final CrashReporter _crashReporter;

  Future<Result<T>> get<T>(
    String path, {
    required Decoder<T> decode,
    Map<String, Object?>? query,
    bool authenticated = true,
    CancelToken? cancelToken,
  }) => _send(
    () => _dio.get<Object?>(
      path,
      queryParameters: query,
      options: _options(authenticated),
      cancelToken: cancelToken,
    ),
    decode,
  );

  Future<Result<T>> post<T>(
    String path, {
    required Decoder<T> decode,
    Object? body,
    bool authenticated = true,
    CancelToken? cancelToken,
  }) => _send(
    () => _dio.post<Object?>(
      path,
      data: body,
      options: _options(authenticated),
      cancelToken: cancelToken,
    ),
    decode,
  );

  Future<Result<T>> put<T>(
    String path, {
    required Decoder<T> decode,
    Object? body,
    CancelToken? cancelToken,
  }) => _send(
    () => _dio.put<Object?>(
      path,
      data: body,
      options: _options(true),
      cancelToken: cancelToken,
    ),
    decode,
  );

  Future<Result<T>> patch<T>(
    String path, {
    required Decoder<T> decode,
    Object? body,
    CancelToken? cancelToken,
  }) => _send(
    () => _dio.patch<Object?>(
      path,
      data: body,
      options: _options(true),
      cancelToken: cancelToken,
    ),
    decode,
  );

  Future<Result<T>> delete<T>(
    String path, {
    required Decoder<T> decode,
    Object? body,
    CancelToken? cancelToken,
  }) => _send(
    () => _dio.delete<Object?>(
      path,
      data: body,
      options: _options(true),
      cancelToken: cancelToken,
    ),
    decode,
  );

  Options _options(bool authenticated) =>
      Options(extra: {RequestFlags.skipAuth: !authenticated});

  Future<Result<T>> _send<T>(
    Future<Response<Object?>> Function() request,
    Decoder<T> decode,
  ) async {
    final Response<Object?> response;
    try {
      response = await request();
    } on DioException catch (exception) {
      final failure = mapDioException(exception);
      if (failure is UnexpectedFailure) {
        await _crashReporter.recordError(
          exception,
          exception.stackTrace,
          reason: 'Unexpected network error',
        );
      }
      return Err(failure);
    }

    try {
      return Ok(decode(response.data));
    } catch (error, stackTrace) {
      // The API broke its contract: report it, but never crash the UI.
      await _crashReporter.recordError(
        error,
        stackTrace,
        reason: 'Failed to decode ${response.requestOptions.path}',
      );
      return const Err(UnexpectedFailure('Unexpected response format.'));
    }
  }
}
