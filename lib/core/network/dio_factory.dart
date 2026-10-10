import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:vital_reg_mobile/core/config/app_config.dart';
import 'package:vital_reg_mobile/core/network/interceptors/auth_interceptor.dart';
import 'package:vital_reg_mobile/core/network/interceptors/logging_interceptor.dart';
import 'package:vital_reg_mobile/core/network/interceptors/rate_limit_retry_interceptor.dart';
import 'package:vital_reg_mobile/core/observability/app_logger.dart';
import 'package:vital_reg_mobile/core/session/session_manager.dart';
import 'package:vital_reg_mobile/core/session/token_storage.dart';

/// Builds the app's single [Dio]. Certificate checks are never disabled.
Dio createDio({
  required AppConfig config,
  required TokenStorage tokenStorage,
  required SessionManager sessionManager,
  required AppLogger logger,
}) {
  final options = BaseOptions(
    baseUrl: config.apiBaseUrl,
    connectTimeout: const Duration(seconds: 15),
    sendTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 30),
    contentType: Headers.jsonContentType,
    headers: {Headers.acceptHeader: Headers.jsonContentType},
  );

  final dio = Dio(options);

  dio.interceptors.addAll([
    AuthInterceptor(
      tokenStorage: tokenStorage,
      onSessionExpired: () =>
          sessionManager.end(reason: SessionEndReason.expired),
    ),
    RateLimitRetryInterceptor(dio),
    if (!kReleaseMode) RedactingLogInterceptor(logger),
  ]);

  return dio;
}
