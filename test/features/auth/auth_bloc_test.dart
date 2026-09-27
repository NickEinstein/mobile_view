import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vital_reg_mobile/core/error/failure.dart';
import 'package:vital_reg_mobile/core/result/result.dart';
import 'package:vital_reg_mobile/core/session/auth_tokens.dart';
import 'package:vital_reg_mobile/core/session/session_manager.dart';
import 'package:vital_reg_mobile/features/auth/domain/auth_repository.dart';
import 'package:vital_reg_mobile/features/auth/domain/entities/permission.dart';
import 'package:vital_reg_mobile/features/auth/domain/entities/user.dart';
import 'package:vital_reg_mobile/features/auth/presentation/bloc/auth_bloc.dart';

import '../../helpers/fakes.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

const _user = User(id: '1', fullName: 'Ada', role: UserRole.registrar);
const _tokens = AuthTokens(accessToken: 'a', refreshToken: 'r');

void main() {
  late SessionManager session;
  late _MockAuthRepository repository;

  setUpAll(() => registerFallbackValue(SessionEndReason.userInitiated));

  setUp(() {
    session = SessionManager(InMemoryTokenStorage());
    repository = _MockAuthRepository();
    // Mirror the real implementation: signing out ends the session.
    when(() => repository.signOut(reason: any(named: 'reason'))).thenAnswer(
      (invocation) => session.end(
        reason: invocation.namedArguments[#reason] as SessionEndReason,
      ),
    );
  });

  tearDown(() => session.dispose());

  AuthBloc buildBloc() =>
      AuthBloc(sessionManager: session, repository: repository);

  blocTest<AuthBloc, AuthState>(
    'is unauthenticated when no session is stored',
    build: buildBloc,
    wait: const Duration(milliseconds: 50),
    act: (bloc) => bloc.add(const AuthStarted()),
    expect: () => const [AuthUnauthenticated()],
  );

  blocTest<AuthBloc, AuthState>(
    'restores a stored session and loads the user',
    setUp: () {
      session = SessionManager(InMemoryTokenStorage(_tokens));
      when(
        () => repository.currentUser(),
      ).thenAnswer((_) async => const Ok(_user));
    },
    build: buildBloc,
    wait: const Duration(milliseconds: 50),
    act: (bloc) => bloc.add(const AuthStarted()),
    expect: () => const [AuthAuthenticated(_user)],
  );

  blocTest<AuthBloc, AuthState>(
    'ends the session when the profile cannot be loaded',
    setUp: () {
      session = SessionManager(InMemoryTokenStorage(_tokens));
      when(
        () => repository.currentUser(),
      ).thenAnswer((_) async => const Err(ServerFailure(statusCode: 500)));
    },
    build: buildBloc,
    wait: const Duration(milliseconds: 50),
    act: (bloc) => bloc.add(const AuthStarted()),
    expect: () => const [AuthUnauthenticated(reason: SessionEndReason.invalid)],
  );

  blocTest<AuthBloc, AuthState>(
    'inactivity logout ends the session with its reason',
    setUp: () {
      session = SessionManager(InMemoryTokenStorage(_tokens));
      when(
        () => repository.currentUser(),
      ).thenAnswer((_) async => const Ok(_user));
    },
    build: buildBloc,
    wait: const Duration(milliseconds: 50),
    act: (bloc) async {
      bloc.add(const AuthStarted());
      await Future<void>.delayed(const Duration(milliseconds: 10));
      bloc.add(const AuthLogoutRequested(reason: SessionEndReason.inactivity));
    },
    expect: () => const [
      AuthAuthenticated(_user),
      AuthUnauthenticated(reason: SessionEndReason.inactivity),
    ],
  );
}
