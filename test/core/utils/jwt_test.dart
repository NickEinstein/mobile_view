import 'package:flutter_test/flutter_test.dart';
import 'package:vital_reg_mobile/core/utils/jwt.dart';

import '../../helpers/fakes.dart';

void main() {
  group('Jwt', () {
    test('reads the exp claim', () {
      final expiresAt = DateTime.utc(2030);
      expect(Jwt.expiry(fakeJwt(expiresAt: expiresAt)), expiresAt);
    });

    test('returns null for malformed tokens instead of throwing', () {
      expect(Jwt.claims('not-a-jwt'), isNull);
      expect(Jwt.expiry('a.b.c'), isNull);
    });

    test('isExpired applies the leeway', () {
      final now = DateTime.utc(2030);
      final token = fakeJwt(expiresAt: now.add(const Duration(seconds: 10)));

      expect(Jwt.isExpired(token, now: now), isTrue);
      expect(Jwt.isExpired(token, now: now, leeway: Duration.zero), isFalse);
    });

    test('opaque tokens are never treated as expired', () {
      expect(Jwt.isExpired('opaque-token'), isFalse);
    });
  });
}
