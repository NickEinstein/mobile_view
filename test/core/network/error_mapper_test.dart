import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vital_reg_mobile/core/error/failure.dart';
import 'package:vital_reg_mobile/core/network/error_mapper.dart';

DioException _ofType(DioExceptionType type) => DioException(
  requestOptions: RequestOptions(path: '/x'),
  type: type,
);

DioException _badResponse(int statusCode, Object? data) {
  final request = RequestOptions(path: '/x');
  return DioException(
    requestOptions: request,
    type: DioExceptionType.badResponse,
    response: Response<Object?>(
      requestOptions: request,
      statusCode: statusCode,
      data: data,
    ),
  );
}

void main() {
  group('mapDioException', () {
    test('maps every timeout type to TimeoutFailure', () {
      for (final type in [
        DioExceptionType.connectionTimeout,
        DioExceptionType.sendTimeout,
        DioExceptionType.receiveTimeout,
      ]) {
        expect(mapDioException(_ofType(type)), const TimeoutFailure());
      }
    });

    test('maps connection errors to NetworkFailure', () {
      expect(
        mapDioException(_ofType(DioExceptionType.connectionError)),
        const NetworkFailure(),
      );
    });

    test('maps 422 with field errors to ValidationFailure', () {
      final failure = mapDioException(
        _badResponse(422, {
          'message': 'Invalid data',
          'errors': {
            'dateOfBirth': ['Must be in the past'],
            'nin': 'Required',
          },
        }),
      );

      expect(
        failure,
        const ValidationFailure(
          message: 'Invalid data',
          fieldErrors: {
            'dateOfBirth': ['Must be in the past'],
            'nin': ['Required'],
          },
        ),
      );
    });

    test('takes the first item when message is a list', () {
      final failure = mapDioException(
        _badResponse(400, {
          'message': ['First problem', 'Second problem'],
        }),
      );

      expect(failure.message, 'First problem');
    });

    test('maps auth and lookup status codes', () {
      expect(
        mapDioException(_badResponse(401, null)),
        isA<UnauthorizedFailure>(),
      );
      expect(mapDioException(_badResponse(403, null)), isA<ForbiddenFailure>());
      expect(mapDioException(_badResponse(404, null)), isA<NotFoundFailure>());
    });

    test('maps 5xx to ServerFailure with the status code', () {
      expect(
        mapDioException(_badResponse(503, '<html>Bad gateway</html>')),
        const ServerFailure(statusCode: 503),
      );
    });
  });
}
