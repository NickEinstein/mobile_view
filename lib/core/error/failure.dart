import 'package:equatable/equatable.dart';

/// Expected failures, as a closed set; each has a localized message
/// (`failure_l10n.dart`). [message] is shown only for [ValidationFailure].
sealed class Failure extends Equatable {
  const Failure([this.message]);

  final String? message;

  @override
  List<Object?> get props => [message];
}

final class NetworkFailure extends Failure {
  const NetworkFailure();
}

final class TimeoutFailure extends Failure {
  const TimeoutFailure();
}

final class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure([super.message]);
}

final class ForbiddenFailure extends Failure {
  const ForbiddenFailure([super.message]);
}

final class NotFoundFailure extends Failure {
  const NotFoundFailure([super.message]);
}

final class ValidationFailure extends Failure {
  const ValidationFailure({String? message, this.fieldErrors = const {}})
    : super(message);

  final Map<String, List<String>> fieldErrors;

  @override
  List<Object?> get props => [message, fieldErrors];
}

final class ServerFailure extends Failure {
  const ServerFailure({required this.statusCode, String? message})
    : super(message);

  final int statusCode;

  @override
  List<Object?> get props => [message, statusCode];
}

final class CancelledFailure extends Failure {
  const CancelledFailure();
}

final class UnexpectedFailure extends Failure {
  const UnexpectedFailure([super.message]);
}
