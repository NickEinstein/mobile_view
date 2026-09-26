import 'package:flutter_test/flutter_test.dart';
import 'package:vital_reg_mobile/core/session/auth_tokens.dart';
import 'package:vital_reg_mobile/core/session/session_manager.dart';

import '../../helpers/fakes.dart';

const _tokens = AuthTokens(accessToken: 'a', refreshToken: 'r');

void main() {
  group('SessionManager', () {
    test('restore without stored tokens is unauthenticated', () async {
      final session = SessionManager(InMemoryTokenStorage());

      await session.restore();

      expect(session.status, SessionStatus.unauthenticated);
      expect(session.lastEndReason, isNull);
    });

    test('restore with an expired refresh token ends as expired', () async {
      final expired = AuthTokens(
        accessToken: 'a',
        refreshToken: fakeJwt(expiresAt: DateTime.utc(2000)),
      );
      final storage = InMemoryTokenStorage(expired);
      final session = SessionManager(storage);

      await session.restore();

      expect(session.status, SessionStatus.unauthenticated);
      expect(session.lastEndReason, SessionEndReason.expired);
      expect(await storage.read(), isNull);
    });

    test('start/end emit changes and end is idempotent', () async {
      final session = SessionManager(InMemoryTokenStorage());
      final emitted = <SessionStatus>[];
      final subscription = session.changes.listen(emitted.add);

      await session.start(_tokens);
      await session.end(reason: SessionEndReason.userInitiated);
      await session.end(reason: SessionEndReason.expired);
      await Future<void>.delayed(Duration.zero);

      expect(emitted, [
        SessionStatus.authenticated,
        SessionStatus.unauthenticated,
      ]);
      expect(session.lastEndReason, SessionEndReason.userInitiated);

      await subscription.cancel();
      await session.dispose();
    });
  });
}
