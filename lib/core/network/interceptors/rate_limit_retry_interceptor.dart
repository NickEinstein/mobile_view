import 'dart:async';

import 'package:dio/dio.dart';
import 'package:vital_reg_mobile/core/network/error_mapper.dart';

/// Retries a GET once after a 429 with a short wait. Writes, or longer
/// waits, reach the caller as a `RateLimitedFailure`.
class RateLimitRetryInterceptor extends Interceptor {
  RateLimitRetryInterceptor(
    this._dio, {
    this.maxWait = const Duration(seconds: 5),
    Future<void> Function(Duration delay)? wait,
  }) : _wait = wait ?? Future<void>.delayed;

  final Dio _dio;

  /// Longer waits aren't worth holding the screen for.
  final Duration maxWait;
  final Future<void> Function(Duration delay) _wait;

  static const _retriedKey = 'rateLimitRetried';

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final response = err.response;
    final options = err.requestOptions;
    if (response?.statusCode != 429 ||
        options.method != 'GET' ||
        options.extra[_retriedKey] == true) {
      return handler.next(err);
    }
    final delay = retryAfterOf(response!);
    if (delay > maxWait) return handler.next(err);

    final cancelToken = options.cancelToken;
    await Future.any([_wait(delay), ?cancelToken?.whenCancel]);
    if (cancelToken?.isCancelled ?? false) return handler.next(err);

    options.extra[_retriedKey] = true;
    try {
      handler.resolve(await _dio.fetch<Object?>(options));
    } on DioException catch (retryError) {
      handler.next(retryError);
    }
  }
}
