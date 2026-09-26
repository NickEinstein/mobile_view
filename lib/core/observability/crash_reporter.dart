import 'package:vital_reg_mobile/core/observability/app_logger.dart';

/// Where unexpected errors go: Sentry when a DSN is configured, else the
/// log.
abstract interface class CrashReporter {
  Future<void> recordError(
    Object error,
    StackTrace stackTrace, {
    bool fatal = false,
    String? reason,
  });

  /// Attach an opaque user id only. Never names, NINs or other PII.
  Future<void> setUser(String? userId);
}

final class LoggingCrashReporter implements CrashReporter {
  LoggingCrashReporter(this._logger);

  final AppLogger _logger;

  @override
  Future<void> recordError(
    Object error,
    StackTrace stackTrace, {
    bool fatal = false,
    String? reason,
  }) async {
    _logger.error(
      reason ?? (fatal ? 'Fatal error' : 'Error'),
      error,
      stackTrace,
    );
  }

  @override
  Future<void> setUser(String? userId) async {}
}
