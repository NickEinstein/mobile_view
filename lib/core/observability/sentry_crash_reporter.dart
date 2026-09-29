import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:vital_reg_mobile/core/observability/crash_reporter.dart';
import 'package:vital_reg_mobile/core/observability/redactor.dart';

/// Crash reporting without personal data: only the opaque user id, and
/// every event scrubbed on the device first.
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
        ..beforeSend = ((event, hint) => scrubEvent(event))
        ..beforeBreadcrumb = ((breadcrumb, hint) => scrubBreadcrumb(breadcrumb))
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

/// Removes personal data from an event. A `FormatException` keeps only its
/// first line (the rest may be a response body).
@visibleForTesting
SentryEvent scrubEvent(SentryEvent event) {
  event.request = null;
  final message = event.message;
  if (message != null) {
    message
      ..formatted = Redactor.redactText(message.formatted)
      ..params = null;
  }
  for (final exception in event.exceptions ?? const <SentryException>[]) {
    final value = exception.value;
    if (value == null) continue;
    final kept = exception.throwable is FormatException
        ? value.split('\n').first
        : value;
    exception.value = Redactor.redactText(kept);
  }
  event.breadcrumbs?.forEach(scrubBreadcrumb);
  return event;
}

/// Removes personal data from a breadcrumb, e.g. a NIN in a route path.
@visibleForTesting
Breadcrumb? scrubBreadcrumb(Breadcrumb? breadcrumb) {
  if (breadcrumb == null) return null;
  final message = breadcrumb.message;
  if (message != null) breadcrumb.message = Redactor.redactText(message);
  final data = breadcrumb.data;
  if (data != null) {
    breadcrumb.data = {
      for (final MapEntry(:key, :value) in data.entries)
        key: Redactor.isSensitive(key)
            ? Redactor.mask
            : value is String
            ? Redactor.redactText(value)
            : Redactor.redact(value),
    };
  }
  return breadcrumb;
}
