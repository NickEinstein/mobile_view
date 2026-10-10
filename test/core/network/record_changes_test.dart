import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vital_reg_mobile/core/network/api_client.dart';
import 'package:vital_reg_mobile/core/network/record_changes.dart';
import 'package:vital_reg_mobile/core/observability/crash_reporter.dart';

/// Answers every request with [status].
class _StatusAdapter implements HttpClientAdapter {
  int status = 200;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    '{}',
    status,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );

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
  late _StatusAdapter adapter;
  late RecordChanges changes;
  late ApiClient client;

  setUp(() {
    adapter = _StatusAdapter();
    changes = RecordChanges();
    client = ApiClient(
      Dio()..httpClientAdapter = adapter,
      _SilentCrashReporter(),
      changes: changes,
    );
  });

  Object? decode(Object? json) => json;

  test('each successful write counts as a change', () async {
    await client.post('/a', decode: decode);
    await client.put('/a', decode: decode);
    await client.patch('/a', decode: decode);
    await client.delete('/a', decode: decode);
    expect(changes.version, 4);
  });

  test('a read does not', () async {
    await client.get('/a', decode: decode);
    expect(changes.version, 0);
  });

  test('a failed write does not', () async {
    adapter.status = 400;
    await client.post('/a', decode: decode);
    expect(changes.version, 0);
  });

  test('a write whose answer cannot be decoded still does', () async {
    await client.post<int>(
      '/a',
      decode: (_) => throw const FormatException('bad'),
    );
    expect(changes.version, 1);
  });
}
