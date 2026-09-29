import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:vital_reg_mobile/core/observability/sentry_crash_reporter.dart';

void main() {
  group('scrubEvent', () {
    test('masks NINs and emails in exception values', () {
      final event = SentryEvent(
        exceptions: [
          SentryException(
            type: 'StateError',
            value: 'No record for NIN 12345678901 (ada@example.com)',
            throwable: StateError('x'),
          ),
        ],
      );

      final value = scrubEvent(event).exceptions!.single.value;

      expect(value, 'No record for NIN *** (***)');
    });

    test("drops a FormatException's input excerpt", () {
      const error = FormatException(
        'Unexpected character',
        '{"fullName": "Ada Lovelace", "nin": "12345678901"',
      );
      final event = SentryEvent(
        exceptions: [
          SentryException(
            type: 'FormatException',
            value: error.toString(),
            throwable: error,
          ),
        ],
      );

      final value = scrubEvent(event).exceptions!.single.value!;

      expect(value, 'FormatException: Unexpected character');
      expect(value, isNot(contains('Ada')));
    });

    test('masks the message and drops the request', () {
      final event = SentryEvent(
        message: SentryMessage('Lookup failed for 08012345678'),
        request: SentryRequest(url: 'https://api.example/nin/12345678901'),
      );

      final scrubbed = scrubEvent(event);

      expect(scrubbed.message!.formatted, 'Lookup failed for ***');
      expect(scrubbed.request, isNull);
    });
  });

  test('scrubBreadcrumb masks sensitive keys and values', () {
    final breadcrumb = Breadcrumb(
      message: 'Opened /records/12345678901',
      data: {'to': '/records/12345678901', 'email': 'a@b.co', 'step': 2},
    );

    final scrubbed = scrubBreadcrumb(breadcrumb)!;

    expect(scrubbed.message, 'Opened /records/***');
    expect(scrubbed.data, {'to': '/records/***', 'email': '***', 'step': 2});
  });
}
