import 'package:flutter_test/flutter_test.dart';
import 'package:vital_reg_mobile/app/router/redirect.dart';
import 'package:vital_reg_mobile/features/auth/domain/entities/permission.dart';
import 'package:vital_reg_mobile/features/auth/domain/entities/user.dart';
import 'package:vital_reg_mobile/features/auth/presentation/bloc/auth_bloc.dart';

const _registrar = User(id: '1', fullName: 'Ada', role: UserRole.registrar);
const _signedIn = AuthAuthenticated(_registrar);

String? _redirect(AuthState auth, String location, {bool onboarded = true}) =>
    resolveRedirect(
      auth: auth,
      location: Uri.parse(location),
      onboardingCompleted: onboarded,
    );

void main() {
  group('while the session is being restored', () {
    test('stays on splash', () {
      expect(_redirect(const AuthUnknown(), '/splash'), isNull);
    });

    test('parks deep links on splash and remembers them', () {
      final target = Uri.parse(_redirect(const AuthUnknown(), '/approvals')!);

      expect(target.path, '/splash');
      expect(target.queryParameters['from'], '/approvals');
    });
  });

  group('when signed out', () {
    test('allows the login page', () {
      expect(_redirect(const AuthUnauthenticated(), '/login'), isNull);
    });

    test('sends protected routes to login with a return path', () {
      final target = Uri.parse(
        _redirect(const AuthUnauthenticated(), '/registrations/birth')!,
      );

      expect(target.path, '/login');
      expect(target.queryParameters['from'], '/registrations/birth');
    });

    test('carries the return path from splash to login', () {
      final target = Uri.parse(
        _redirect(const AuthUnauthenticated(), '/splash?from=%2Freports')!,
      );

      expect(target.path, '/login');
      expect(target.queryParameters['from'], '/reports');
    });
  });

  group('when signed in', () {
    test('leaves login for home', () {
      expect(_redirect(_signedIn, '/login'), '/');
    });

    test('returns to the remembered route', () {
      expect(
        _redirect(_signedIn, '/login?from=%2Fregistrations%2Fbirth'),
        '/registrations/birth',
      );
    });

    test('ignores external return paths (open redirect)', () {
      expect(_redirect(_signedIn, '/login?from=%2F%2Fevil.example'), '/');
    });

    test('blocks modules the role lacks permission for', () {
      expect(_redirect(_signedIn, '/approvals'), '/');
      expect(_redirect(_signedIn, '/approvals/42'), '/');
    });

    test('allows modules the role has permission for', () {
      expect(_redirect(_signedIn, '/registrations/birth'), isNull);
      expect(_redirect(_signedIn, '/'), isNull);
    });
  });

  group('on first launch (onboarding not completed)', () {
    test('sends signed-out users to onboarding instead of login', () {
      expect(
        _redirect(const AuthUnauthenticated(), '/login', onboarded: false),
        '/onboarding',
      );
    });

    test('stays on onboarding', () {
      expect(
        _redirect(const AuthUnauthenticated(), '/onboarding', onboarded: false),
        isNull,
      );
    });

    test('keeps the deep link through onboarding', () {
      final target = Uri.parse(
        _redirect(
          const AuthUnauthenticated(),
          '/splash?from=%2Freports',
          onboarded: false,
        )!,
      );

      expect(target.path, '/onboarding');
      expect(target.queryParameters['from'], '/reports');
    });

    test('moves on to login once completed, keeping the deep link', () {
      final target = Uri.parse(
        _redirect(const AuthUnauthenticated(), '/onboarding?from=%2Freports')!,
      );

      expect(target.path, '/login');
      expect(target.queryParameters['from'], '/reports');
    });

    test('is skipped for users who are already signed in', () {
      expect(_redirect(_signedIn, '/onboarding', onboarded: false), '/');
      expect(_redirect(_signedIn, '/', onboarded: false), isNull);
    });
  });
}
