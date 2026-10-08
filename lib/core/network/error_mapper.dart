import 'package:dio/dio.dart';
import 'package:vital_reg_mobile/core/error/failure.dart';

/// Maps every Dio error to a [Failure]. The switches are exhaustive, so a new
/// `DioExceptionType` is a compile error rather than a silent crash.
Failure mapDioException(DioException exception) => switch (exception.type) {
  DioExceptionType.connectionTimeout ||
  DioExceptionType.sendTimeout ||
  DioExceptionType.receiveTimeout ||
  DioExceptionType.transformTimeout => const TimeoutFailure(),
  DioExceptionType.connectionError ||
  DioExceptionType.badCertificate => const NetworkFailure(),
  DioExceptionType.cancel => const CancelledFailure(),
  DioExceptionType.badResponse => _fromResponse(exception.response),
  DioExceptionType.unknown => UnexpectedFailure(exception.message),
};

Failure _fromResponse(Response<Object?>? response) {
  final data = response?.data;
  final message = extractMessage(data);
  return switch (response?.statusCode) {
    400 || 422 => ValidationFailure(
      message: message,
      fieldErrors: extractFieldErrors(data),
    ),
    401 => UnauthorizedFailure(message),
    403 => ForbiddenFailure(message),
    404 => NotFoundFailure(message),
    final int code => ServerFailure(statusCode: code, message: message),
    null => UnexpectedFailure(message),
  };
}

/// The error message, whether the body's `message` is a string or a list.
String? extractMessage(Object? data) {
  if (data is! Map<Object?, Object?>) return null;
  final message = data['message'];
  if (message is String && message.isNotEmpty) return message;
  if (message is List<Object?> && message.isNotEmpty) {
    return '${message.first}';
  }
  final error = data['error'];
  if (error is String && error.isNotEmpty) return error;
  return null;
}

Map<String, List<String>> extractFieldErrors(Object? data) {
  if (data is! Map<Object?, Object?>) return const {};
  final errors = data['errors'];
  if (errors is! Map<Object?, Object?>) return const {};
  return {
    for (final MapEntry(key: field, value: value) in errors.entries)
      '$field': value is List<Object?>
          ? [for (final v in value) '$v']
          : ['$value'],
  };
}
