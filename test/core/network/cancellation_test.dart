import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vital_reg_mobile/core/error/failure.dart';
import 'package:vital_reg_mobile/core/network/api_client.dart';
import 'package:vital_reg_mobile/core/network/cancellation.dart';
import 'package:vital_reg_mobile/core/observability/crash_reporter.dart';
import 'package:vital_reg_mobile/core/result/result.dart';

/// Never answers, like an upload still in progress.
class _HangingAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) => Completer<ResponseBody>().future;

  @override
  void close({bool force = false}) {}
}

class _SilentCrashReporter implements CrashReporter {
  final List<Object> recorded = [];

  @override
  Future<void> recordError(
    Object error,
    StackTrace stackTrace, {
    bool fatal = false,
    String? reason,
  }) async => recorded.add(error);

  @override
  Future<void> setUser(String? userId) async {}
}

void main() {
  group('Cancellation', () {
    test('runs listeners once, and late ones at once', () {
      final cancellation = Cancellation();
      var calls = 0;
      cancellation
        ..onCancel(() => calls++)
        ..cancel()
        ..cancel();
      expect(calls, 1);

      cancellation.onCancel(() => calls++);
      expect(calls, 2);
      expect(cancellation.isCancelled, isTrue);
    });
  });

  test(
    'a cancelled request ends with a CancelledFailure, not a report',
    () async {
      final reporter = _SilentCrashReporter();
      final client = ApiClient(
        Dio(BaseOptions(baseUrl: 'https://api.test'))
          ..httpClientAdapter = _HangingAdapter(),
        reporter,
      );
      final cancellation = Cancellation();

      final pending = client.post<void>(
        '/uploads',
        body: {'file': 'x'},
        cancellation: cancellation,
        decode: (_) {},
      );
      cancellation.cancel();

      expect(await pending, const Err<void>(CancelledFailure()));
      expect(reporter.recorded, isEmpty);
    },
  );
}
