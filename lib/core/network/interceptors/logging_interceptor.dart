import 'package:dio/dio.dart';
import 'package:vital_reg_mobile/core/observability/app_logger.dart';
import 'package:vital_reg_mobile/core/observability/redactor.dart';

/// Debug-only request log, redacted; response bodies are never logged.
class RedactingLogInterceptor extends Interceptor {
  RedactingLogInterceptor(this._logger);

  final AppLogger _logger;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    _logger.debug(
      '→ ${options.method} ${options.path}\n'
      'query: ${Redactor.redact(options.queryParameters)}\n'
      'headers: ${Redactor.redact(options.headers)}\n'
      'body: ${Redactor.redact(_body(options.data))}',
    );
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    final request = response.requestOptions;
    _logger.debug('← ${response.statusCode} ${request.method} ${request.path}');
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final request = err.requestOptions;
    _logger.warning(
      '✕ ${err.response?.statusCode ?? err.type.name} '
      '${request.method} ${request.path}',
    );
    handler.next(err);
  }

  Object? _body(Object? data) => data is FormData
      ? {for (final field in data.fields) field.key: field.value}
      : data;
}
