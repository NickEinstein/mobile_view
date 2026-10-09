import 'package:vital_reg_mobile/core/error/failure.dart';
import 'package:vital_reg_mobile/l10n/gen/app_localizations.dart';

/// Every [Failure] gets a user-facing, localized message. The switch is
/// exhaustive, so a new failure type won't compile until it has copy.
extension FailureL10n on Failure {
  String localize(AppLocalizations l10n) => switch (this) {
    NetworkFailure() => l10n.errorNetwork,
    TimeoutFailure() => l10n.errorTimeout,
    UnauthorizedFailure() => l10n.errorUnauthorized,
    ForbiddenFailure() => l10n.errorForbidden,
    NotFoundFailure() => l10n.errorNotFound,
    ValidationFailure(:final message) => message ?? l10n.errorValidation,
    RateLimitedFailure(:final retryAfter) => l10n.errorRateLimited(
      retryAfter.inSeconds < 1 ? 1 : retryAfter.inSeconds,
    ),
    ServerFailure() => l10n.errorServer,
    CancelledFailure() || UnexpectedFailure() => l10n.errorUnexpected,
  };
}
