import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vital_reg_mobile/core/error/failure.dart';
import 'package:vital_reg_mobile/core/network/api_client.dart';
import 'package:vital_reg_mobile/core/network/interceptors/rate_limit_retry_interceptor.dart';
import 'package:vital_reg_mobile/core/observability/crash_reporter.dart';
import 'package:vital_reg_mobile/core/result/result.dart';

/// The API's 429 body, as its throttler guard sends it.
Map<String, Object?> _throttled(Object? retryAfter) => {
  'statusCode': 429,
  'message': 'Too many requests. Please try again later.',
  'error': 'Too Many Requests',
  'retryAfter': retryAfter,
};

/// Answers with each of [replies] in turn: (status, body).
class _Replies implements HttpClientAdapter {
  _Replies(this.replies);

  final List<(int, Object?)> replies;
  final List<String> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options.method);
    final (status, body) = replies.removeAt(0);
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _SilentCrashReporter implements CrashReporter {
  @override
  Future<void> recordError(
    Object error,
    StackTrace stackTrace, {
    bool fatal = false,
    String? reason,
  }) async {}

  @override
  Future<void> setUser(String? userId) async {}
}

void main() {
  late List<Duration> waits;

  ({ApiClient client, _Replies adapter}) build(List<(int, Object?)> replies) {
    final adapter = _Replies(replies);
    final dio = Dio()..httpClientAdapter = adapter;
    dio.interceptors.add(
      RateLimitRetryInterceptor(dio, wait: (delay) async => waits.add(delay)),
    );
    return (client: ApiClient(dio, _SilentCrashReporter()), adapter: adapter);
  }

  Object? decode(Object? json) => json;

  setUp(() => waits = []);

  test('a read turned away briefly waits as asked and tries again', () async {
    final (:client, :adapter) = build([
      (429, _throttled(1)),
      (200, {'ok': true}),
    ]);

    final result = await client.get('/death-registration/list', decode: decode);

    expect(result, const Ok<Object?>({'ok': true}));
    expect(waits, [const Duration(seconds: 1)]);
    expect(adapter.requests, ['GET', 'GET']);
  });

  test('only once: a second 429 says how long to wait', () async {
    final (:client, :adapter) = build([
      (429, _throttled(1)),
      (429, _throttled(2)),
    ]);

    final result = await client.get('/death-registration/list', decode: decode);

    expect(
      result,
      const Err<Object?>(
        RateLimitedFailure(
          retryAfter: Duration(seconds: 2),
          message: 'Too many requests. Please try again later.',
        ),
      ),
    );
    expect(adapter.requests, hasLength(2));
  });

  test('a write is not repeated', () async {
    final (:client, :adapter) = build([(429, _throttled(1))]);

    final result = await client.post('/birth-registration/add', decode: decode);

    expect(result, isA<Err<Object?>>());
    expect(adapter.requests, ['POST']);
    expect(waits, isEmpty);
  });

  test('a long wait is left to the user', () async {
    final (:client, :adapter) = build([(429, _throttled(30))]);

    final result = await client.get('/death-registration/list', decode: decode);

    expect(
      (result as Err).failure,
      isA<RateLimitedFailure>().having(
        (f) => f.retryAfter,
        'retryAfter',
        const Duration(seconds: 30),
      ),
    );
    expect(adapter.requests, ['GET']);
  });

  test('without a retryAfter, one second is assumed', () async {
    final (:client, :adapter) = build([
      (429, {'message': 'Too many requests.'}),
      (200, null),
    ]);

    await client.get('/x', decode: decode);

    expect(waits, [const Duration(seconds: 1)]);
  });
}
