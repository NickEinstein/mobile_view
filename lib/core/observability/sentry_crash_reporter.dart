import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:vital_reg_mobile/core/observability/crash_reporter.dart';

/// Staging/production crash reporting.
///
/// `sendDefaultPii` is off: no IP addresses, no request bodies. The only
/// identity attached is the opaque user id from [setUser].
final class SentryCrashReporter implements CrashReporter {
  SentryCrashReporter._();

  static Future<SentryCrashReporter> init({
    required String dsn,
    required String environment,
  }) async {
    await SentryFlutter.init((options) {
      options
        ..dsn = dsn
        ..environment = environment
        ..sendDefaultPii = false
        ..tracesSampleRate = 0.2;
    });
    return SentryCrashReporter._();
  }

  @override
  Future<void> recordError(
    Object error,
    StackTrace stackTrace, {
    bool fatal = false,
    String? reason,
  }) async {
    await Sentry.captureException(
      error,
      stackTrace: stackTrace,
      hint: reason == null ? null : Hint.withMap({'reason': reason}),
    );
  }

  @override
  Future<void> setUser(String? userId) async {
    await Sentry.configureScope(
      (scope) => scope.setUser(userId == null ? null : SentryUser(id: userId)),
    );
  }
}
