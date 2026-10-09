import 'package:dio/dio.dart';
import 'package:vital_reg_mobile/core/error/failure.dart';
import 'package:vital_reg_mobile/core/network/cancellation.dart';
import 'package:vital_reg_mobile/core/network/error_mapper.dart';
import 'package:vital_reg_mobile/core/network/record_changes.dart';
import 'package:vital_reg_mobile/core/network/request_flags.dart';
import 'package:vital_reg_mobile/core/observability/crash_reporter.dart';
import 'package:vital_reg_mobile/core/result/result.dart';

typedef Decoder<T> = T Function(Object? json);

/// The only class that talks to Dio: every call decodes to a typed
/// [Result]. Used by repositories only.
class ApiClient {
  ApiClient(this._dio, this._crashReporter, {RecordChanges? changes})
    : _changes = changes ?? recordChanges;

  final Dio _dio;
  final CrashReporter _crashReporter;
  final RecordChanges _changes;

  Future<Result<T>> get<T>(
    String path, {
    required Decoder<T> decode,
    Map<String, Object?>? query,
    bool authenticated = true,
    Cancellation? cancellation,
  }) => _send(
    () => _dio.get<Object?>(
      path,
      queryParameters: query,
      options: _options(authenticated),
      cancelToken: _token(cancellation),
    ),
    decode,
  );

  /// [body] may be a `FormData` for file uploads; [onSendProgress] then
  /// reports bytes sent and total.
  Future<Result<T>> post<T>(
    String path, {
    required Decoder<T> decode,
    Object? body,
    bool authenticated = true,
    Map<String, String>? headers,
    ProgressCallback? onSendProgress,
    Cancellation? cancellation,
  }) => _send(
    () => _dio.post<Object?>(
      path,
      data: body,
      options: _options(authenticated).copyWith(headers: headers),
      onSendProgress: onSendProgress,
      cancelToken: _token(cancellation),
    ),
    decode,
    write: true,
  );

  /// With [authenticated] false and a full URL in [path], uploads to
  /// storage (e.g. a presigned upload URL).
  Future<Result<T>> put<T>(
    String path, {
    required Decoder<T> decode,
    Object? body,
    bool authenticated = true,
    Map<String, Object?>? headers,
    Cancellation? cancellation,
  }) => _send(
    () => _dio.put<Object?>(
      path,
      data: body,
      options: _options(authenticated).copyWith(headers: headers),
      cancelToken: _token(cancellation),
    ),
    decode,
    write: true,
  );

  Future<Result<T>> patch<T>(
    String path, {
    required Decoder<T> decode,
    Object? body,
    Cancellation? cancellation,
  }) => _send(
    () => _dio.patch<Object?>(
      path,
      data: body,
      options: _options(true),
      cancelToken: _token(cancellation),
    ),
    decode,
    write: true,
  );

  Future<Result<T>> delete<T>(
    String path, {
    required Decoder<T> decode,
    Object? body,
    Cancellation? cancellation,
  }) => _send(
    () => _dio.delete<Object?>(
      path,
      data: body,
      options: _options(true),
      cancelToken: _token(cancellation),
    ),
    decode,
    write: true,
  );

  static CancelToken? _token(Cancellation? cancellation) {
    if (cancellation == null) return null;
    final token = CancelToken();
    cancellation.onCancel(token.cancel);
    return token;
  }

  Options _options(bool authenticated) =>
      Options(extra: {RequestFlags.skipAuth: !authenticated});

  /// A successful [write] bumps [RecordChanges].
  Future<Result<T>> _send<T>(
    Future<Response<Object?>> Function() request,
    Decoder<T> decode, {
    bool write = false,
  }) async {
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
    // The server took the write, even if its answer can't be decoded.
    if (write) _changes.bump();

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
