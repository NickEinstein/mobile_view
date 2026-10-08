import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vital_reg_mobile/core/network/interceptors/auth_interceptor.dart';
import 'package:vital_reg_mobile/core/network/request_flags.dart';
import 'package:vital_reg_mobile/core/session/auth_tokens.dart';

import '../../helpers/fakes.dart';

/// Answers 200 only when the request carries `Bearer <validToken>`.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.validToken);

  String validToken;
  final List<RequestOptions> requests = [];

  /// Runs while the request is in flight.
  Future<void> Function()? whileSending;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    await whileSending?.call();
    final authorized = options.headers['Authorization'] == 'Bearer $validToken';
    return ResponseBody.fromString(
      authorized ? '{"ok":true}' : '{"message":"token expired"}',
      authorized ? 200 : 401,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late InMemoryTokenStorage storage;
  late _FakeAdapter adapter;
  late Dio dio;
  late int sessionExpiredCalls;

  setUp(() {
    storage = InMemoryTokenStorage(const AuthTokens(accessToken: 'valid'));
    adapter = _FakeAdapter('valid');
    sessionExpiredCalls = 0;

    dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
      ..httpClientAdapter = adapter;
    dio.interceptors.add(
      AuthInterceptor(
        tokenStorage: storage,
        onSessionExpired: () async {
          sessionExpiredCalls++;
        },
      ),
    );
  });

  test('attaches the stored access token', () async {
    final response = await dio.get<Object?>('/records');

    expect(response.statusCode, 200);
    expect(adapter.requests.single.headers['Authorization'], 'Bearer valid');
    expect(sessionExpiredCalls, 0);
  });

  test('a rejected token ends the session, with no retry', () async {
    adapter.validToken = 'something-else';

    await expectLater(
      dio.get<Object?>('/records'),
      throwsA(isA<DioException>()),
    );

    expect(sessionExpiredCalls, 1);
    expect(adapter.requests, hasLength(1));
  });

  test('a late 401 for a replaced token leaves the new session', () async {
    adapter
      ..validToken = 'something-else'
      // The user signs in again before the old request's answer arrives.
      ..whileSending = () =>
          storage.write(const AuthTokens(accessToken: 'newer'));

    await expectLater(
      dio.get<Object?>('/records'),
      throwsA(isA<DioException>()),
    );
    expect(sessionExpiredCalls, 0);
  });

  test('a 401 on a public request is an answer, not an expiry', () async {
    await expectLater(
      dio.get<Object?>(
        '/public',
        options: Options(extra: {RequestFlags.skipAuth: true}),
      ),
      throwsA(isA<DioException>()),
    );

    expect(
      adapter.requests.single.headers.containsKey('Authorization'),
      isFalse,
    );
    expect(sessionExpiredCalls, 0);
  });
}
