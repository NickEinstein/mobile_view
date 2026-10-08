import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vital_reg_mobile/core/error/failure.dart';
import 'package:vital_reg_mobile/core/result/result.dart';
import 'package:vital_reg_mobile/features/auth/domain/auth_repository.dart';
import 'package:vital_reg_mobile/features/auth/domain/value_objects/credentials.dart';
import 'package:vital_reg_mobile/features/auth/presentation/password_reset/cubit/password_reset_cubit.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

const _email = Email.dirty('michealjames@mail.com');

void main() {
  late _MockAuthRepository repository;

  setUpAll(() {
    registerFallbackValue(const Email.pure());
    registerFallbackValue(const OtpCode.pure());
    registerFallbackValue(const Password.pure());
  });

  setUp(() => repository = _MockAuthRepository());

  // Cooldown off so no timer runs during tests.
  PasswordResetCubit build() =>
      PasswordResetCubit(repository, resendCooldownSeconds: 0);

  group('credentials', () {
    test('masks the email for display', () {
      expect(_email.masked, 'mic*********@mail.com');
      expect(const Email.dirty('ab@x.io').masked, 'a*@x.io');
    });

    test('a code needs exactly 4 digits', () {
      expect(const OtpCode.dirty('123').isValid, isFalse);
      expect(const OtpCode.dirty('12a4').isValid, isFalse);
      expect(const OtpCode.dirty('1234').isValid, isTrue);
    });

    test('confirmation must match the new password', () {
      expect(
        const ConfirmedPassword.dirty(
          original: 'secret-1',
          value: 'secret-2',
        ).error,
        ConfirmedPasswordError.mismatch,
      );
      expect(
        const ConfirmedPassword.dirty(
          original: 'secret-1',
          value: 'secret-1',
        ).isValid,
        isTrue,
      );
    });
  });

  blocTest<PasswordResetCubit, PasswordResetState>(
    'does not call the API for an invalid email',
    build: build,
    act: (cubit) async {
      cubit.emailChanged('not-an-email');
      await cubit.sendCode();
    },
    verify: (_) => verifyNever(
      () => repository.requestPasswordReset(email: any(named: 'email')),
    ),
  );

  blocTest<PasswordResetCubit, PasswordResetState>(
    'moves to the code step once the code is sent',
    setUp: () => when(
      () => repository.requestPasswordReset(email: any(named: 'email')),
    ).thenAnswer((_) async => const Ok(null)),
    build: build,
    act: (cubit) async {
      cubit.emailChanged(_email.value);
      await cubit.sendCode();
    },
    verify: (cubit) => expect(cubit.state.step, PasswordResetStep.code),
  );

  blocTest<PasswordResetCubit, PasswordResetState>(
    'keeps the email step and shows the error when sending fails',
    setUp: () => when(
      () => repository.requestPasswordReset(email: any(named: 'email')),
    ).thenAnswer((_) async => const Err(NetworkFailure())),
    build: build,
    act: (cubit) async {
      cubit.emailChanged(_email.value);
      await cubit.sendCode();
    },
    verify: (cubit) {
      expect(cubit.state.step, PasswordResetStep.email);
      expect(cubit.state.failure, const NetworkFailure());
    },
  );

  blocTest<PasswordResetCubit, PasswordResetState>(
    'a correct code yields a reset token and the verified step',
    setUp: () => when(
      () => repository.verifyPasswordResetCode(
        email: any(named: 'email'),
        code: any(named: 'code'),
      ),
    ).thenAnswer((_) async => const Ok('reset-token')),
    build: build,
    seed: () =>
        const PasswordResetState(step: PasswordResetStep.code, email: _email),
    act: (cubit) async {
      cubit.codeChanged('1234');
      await cubit.verifyCode();
    },
    verify: (cubit) {
      expect(cubit.state.step, PasswordResetStep.verified);
      expect(cubit.state.resetToken, 'reset-token');
    },
  );

  blocTest<PasswordResetCubit, PasswordResetState>(
    'closing the code dialog returns to the email step',
    build: build,
    seed: () => const PasswordResetState(step: PasswordResetStep.code),
    act: (cubit) => cubit.codeDismissed(),
    verify: (cubit) => expect(cubit.state.step, PasswordResetStep.email),
  );

  blocTest<PasswordResetCubit, PasswordResetState>(
    'mismatched passwords are rejected without calling the API',
    build: build,
    seed: () => const PasswordResetState(
      step: PasswordResetStep.newPassword,
      resetToken: 'reset-token',
    ),
    act: (cubit) async {
      cubit
        ..passwordChanged('new-password-1')
        ..confirmationChanged('new-password-2');
      await cubit.resetPassword();
    },
    verify: (cubit) {
      expect(
        cubit.state.confirmation.displayError,
        ConfirmedPasswordError.mismatch,
      );
      verifyNever(
        () => repository.resetPassword(
          resetToken: any(named: 'resetToken'),
          password: any(named: 'password'),
        ),
      );
    },
  );

  blocTest<PasswordResetCubit, PasswordResetState>(
    'resets the password with the token and finishes',
    setUp: () => when(
      () => repository.resetPassword(
        resetToken: any(named: 'resetToken'),
        password: any(named: 'password'),
      ),
    ).thenAnswer((_) async => const Ok(null)),
    build: build,
    seed: () => const PasswordResetState(
      step: PasswordResetStep.newPassword,
      resetToken: 'reset-token',
    ),
    act: (cubit) async {
      cubit
        ..passwordChanged('new-password-1')
        ..confirmationChanged('new-password-1');
      await cubit.resetPassword();
    },
    verify: (cubit) {
      expect(cubit.state.step, PasswordResetStep.done);
      verify(
        () => repository.resetPassword(
          resetToken: 'reset-token',
          password: const Password.dirty('new-password-1'),
        ),
      ).called(1);
    },
  );
}
