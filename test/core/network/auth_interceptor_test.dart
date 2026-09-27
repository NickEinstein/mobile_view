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

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
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
  late int refreshCalls;
  late int sessionExpiredCalls;
  late AuthTokens? refreshResult;

  setUp(() {
    storage = InMemoryTokenStorage(
      const AuthTokens(accessToken: 'old', refreshToken: 'refresh-1'),
    );
    adapter = _FakeAdapter('new');
    refreshCalls = 0;
    sessionExpiredCalls = 0;
    refreshResult = const AuthTokens(
      accessToken: 'new',
      refreshToken: 'refresh-2',
    );

    dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
      ..httpClientAdapter = adapter;
    dio.interceptors.add(
      AuthInterceptor(
        dio: dio,
        tokenStorage: storage,
        refresh: (refreshToken) async {
          refreshCalls++;
          await Future<void>.delayed(const Duration(milliseconds: 10));
          return refreshResult;
        },
        onSessionExpired: () async {
          sessionExpiredCalls++;
        },
      ),
    );
  });

  test('attaches the stored access token', () async {
    adapter.validToken = 'old';

    final response = await dio.get<Object?>('/me');

    expect(response.statusCode, 200);
    expect(adapter.requests.single.headers['Authorization'], 'Bearer old');
    expect(refreshCalls, 0);
  });

  test('parallel 401s trigger ONE refresh and every request retries', () async {
    final responses = await Future.wait([
      dio.get<Object?>('/a'),
      dio.get<Object?>('/b'),
      dio.get<Object?>('/c'),
    ]);

    expect(responses.map((r) => r.statusCode), everyElement(200));
    expect(refreshCalls, 1);
    expect((await storage.read())?.accessToken, 'new');
    expect(sessionExpiredCalls, 0);
  });

  test('ends the session when the refresh is rejected', () async {
    refreshResult = null;

    await expectLater(dio.get<Object?>('/a'), throwsA(isA<DioException>()));
    expect(sessionExpiredCalls, 1);
  });

  test('public requests carry no token and never refresh', () async {
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
    expect(refreshCalls, 0);
  });
}
