import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vital_reg_mobile/core/error/failure.dart';
import 'package:vital_reg_mobile/core/result/result.dart';
import 'package:vital_reg_mobile/features/auth/domain/auth_repository.dart';
import 'package:vital_reg_mobile/features/auth/domain/value_objects/credentials.dart';
import 'package:vital_reg_mobile/features/auth/presentation/login/cubit/login_cubit.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  group('Email', () {
    test('rejects empty and malformed addresses', () {
      expect(const Email.dirty().error, EmailError.empty);
      expect(const Email.dirty('ada@').error, EmailError.invalid);
      expect(const Email.dirty('ada example.com').error, EmailError.invalid);
      expect(const Email.dirty(' ada@example.com ').isValid, isTrue);
    });
  });

  test('canSubmit needs text in both fields', () {
    expect(const LoginState().canSubmit, isFalse);
    expect(const LoginState(email: Email.dirty('a@b.co')).canSubmit, isFalse);
    expect(
      const LoginState(
        email: Email.dirty('a@b.co'),
        password: Password.dirty('x'),
      ).canSubmit,
      isTrue,
    );
  });

  late _MockAuthRepository repository;

  setUpAll(() {
    registerFallbackValue(const Email.pure());
    registerFallbackValue(const Password.pure());
  });

  setUp(() => repository = _MockAuthRepository());

  void stubSignIn(Result<void> result) => when(
    () => repository.signIn(
      email: any(named: 'email'),
      password: any(named: 'password'),
    ),
  ).thenAnswer((_) async => result);

  Future<void> fillAndSubmit(LoginCubit cubit) async {
    cubit
      ..emailChanged('ada@example.com')
      ..passwordChanged('correct-horse');
    await cubit.submit();
  }

  const filled = LoginState(
    email: Email.dirty('ada@example.com'),
    password: Password.dirty('correct-horse'),
  );

  blocTest<LoginCubit, LoginState>(
    'shows validation errors and does not call the API for an empty form',
    build: () => LoginCubit(repository),
    act: (cubit) => cubit.submit(),
    expect: () => const [
      LoginState(email: Email.dirty(), password: Password.dirty()),
    ],
    verify: (_) => verifyNever(
      () => repository.signIn(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ),
  );

  blocTest<LoginCubit, LoginState>(
    'emits submitting then success when sign-in succeeds',
    setUp: () => stubSignIn(const Ok(null)),
    build: () => LoginCubit(repository),
    act: fillAndSubmit,
    skip: 2,
    expect: () => [
      filled.copyWith(status: LoginStatus.submitting),
      filled.copyWith(status: LoginStatus.success),
    ],
  );

  blocTest<LoginCubit, LoginState>(
    'surfaces the failure when sign-in fails',
    setUp: () => stubSignIn(const Err(UnauthorizedFailure())),
    build: () => LoginCubit(repository),
    act: fillAndSubmit,
    skip: 2,
    expect: () => [
      filled.copyWith(status: LoginStatus.submitting),
      filled.copyWith(
        status: LoginStatus.failure,
        failure: const UnauthorizedFailure(),
      ),
    ],
  );
}
