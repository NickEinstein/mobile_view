import 'package:flutter_test/flutter_test.dart';
import 'package:vital_reg_mobile/core/observability/redactor.dart';

void main() {
  group('Redactor', () {
    test('masks secrets and PII at any depth', () {
      final redacted = Redactor.redact({
        'username': 'ada',
        'password': 'hunter22',
        'Authorization': 'Bearer abc',
        'child': {
          'NIN': '12345678901',
          'items': [
            {'refresh_token': 'r', 'status': 'ok'},
          ],
        },
      });

      expect(redacted, {
        'username': 'ada',
        'password': Redactor.mask,
        'Authorization': Redactor.mask,
        'child': {
          'NIN': Redactor.mask,
          'items': [
            {'refresh_token': Redactor.mask, 'status': 'ok'},
          ],
        },
      });
    });

    test('truncates long values such as base64 images', () {
      final redacted = Redactor.redact({'document': 'A' * 5000});

      expect(
        (redacted! as Map<Object?, Object?>)['document'],
        contains('5000 chars'),
      );
    });
  });
}
