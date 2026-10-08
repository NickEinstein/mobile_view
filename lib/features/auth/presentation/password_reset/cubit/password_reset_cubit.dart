import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:formz/formz.dart';
import 'package:vital_reg_mobile/core/error/failure.dart';
import 'package:vital_reg_mobile/core/result/result.dart';
import 'package:vital_reg_mobile/features/auth/domain/auth_repository.dart';
import 'package:vital_reg_mobile/features/auth/domain/value_objects/credentials.dart';

part 'password_reset_state.dart';

/// Forgot password → email code → new password; the view follows
/// [PasswordResetState.step].
class PasswordResetCubit extends Cubit<PasswordResetState> {
  PasswordResetCubit(this._repository, {this.resendCooldownSeconds = 60})
    : super(const PasswordResetState());

  final AuthRepository _repository;

  /// Wait before "Resend OTP" can be used again, to limit repeated emails.
  final int resendCooldownSeconds;

  Timer? _cooldownTimer;

  void emailChanged(String value) =>
      emit(state.copyWith(email: Email.dirty(value)));

  Future<void> sendCode() async {
    if (state.isSubmitting) return;
    final email = Email.dirty(state.email.value);
    if (!email.isValid) {
      emit(state.copyWith(email: email));
      return;
    }

    emit(state.copyWith(email: email, isSubmitting: true));
    final result = await _repository.requestPasswordReset(email: email);
    if (isClosed) return;
    switch (result) {
      case Ok():
        emit(
          state.copyWith(
            step: PasswordResetStep.code,
            code: const OtpCode.pure(),
            isSubmitting: false,
          ),
        );
        _startCooldown();
      case Err(:final failure):
        emit(state.copyWith(isSubmitting: false, failure: failure));
    }
  }

  Future<void> resendCode() async {
    if (state.isSubmitting || state.resendCooldown > 0) return;
    emit(state.copyWith(isSubmitting: true));
    final result = await _repository.requestPasswordReset(email: state.email);
    if (isClosed) return;
    switch (result) {
      case Ok():
        emit(state.copyWith(code: const OtpCode.pure(), isSubmitting: false));
        _startCooldown();
      case Err(:final failure):
        emit(state.copyWith(isSubmitting: false, failure: failure));
    }
  }

  void codeChanged(String value) =>
      emit(state.copyWith(code: OtpCode.dirty(value)));

  Future<void> verifyCode() async {
    if (state.isSubmitting || !state.code.isValid) return;
    emit(state.copyWith(isSubmitting: true));
    final result = await _repository.verifyPasswordResetCode(
      email: state.email,
      code: state.code,
    );
    if (isClosed) return;
    switch (result) {
      case Ok(value: final resetToken):
        _cooldownTimer?.cancel();
        emit(
          state.copyWith(
            step: PasswordResetStep.verified,
            resetToken: resetToken,
            isSubmitting: false,
          ),
        );
      case Err(:final failure):
        emit(state.copyWith(isSubmitting: false, failure: failure));
    }
  }

  /// The code dialog was closed without verifying: back to the email form.
  void codeDismissed() {
    if (state.step != PasswordResetStep.code) return;
    emit(state.copyWith(step: PasswordResetStep.email));
  }

  /// "Proceed" on the verification success dialog.
  void startNewPassword() {
    if (state.step != PasswordResetStep.verified) return;
    emit(state.copyWith(step: PasswordResetStep.newPassword));
  }

  void passwordChanged(String value) => emit(
    state.copyWith(
      password: Password.dirty(value),
      confirmation: state.confirmation.isPure
          ? ConfirmedPassword.pure(original: value)
          : ConfirmedPassword.dirty(
              original: value,
              value: state.confirmation.value,
            ),
    ),
  );

  void confirmationChanged(String value) => emit(
    state.copyWith(
      confirmation: ConfirmedPassword.dirty(
        original: state.password.value,
        value: value,
      ),
    ),
  );

  Future<void> resetPassword() async {
    final resetToken = state.resetToken;
    if (state.isSubmitting || resetToken == null) return;
    final password = Password.dirty(state.password.value);
    final confirmation = ConfirmedPassword.dirty(
      original: password.value,
      value: state.confirmation.value,
    );
    if (!Formz.validate([password, confirmation])) {
      emit(state.copyWith(password: password, confirmation: confirmation));
      return;
    }

    emit(state.copyWith(isSubmitting: true));
    final result = await _repository.resetPassword(
      resetToken: resetToken,
      password: password,
    );
    if (isClosed) return;
    switch (result) {
      case Ok():
        emit(state.copyWith(step: PasswordResetStep.done, isSubmitting: false));
      case Err(:final failure):
        emit(state.copyWith(isSubmitting: false, failure: failure));
    }
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    if (resendCooldownSeconds <= 0) return;
    emit(state.copyWith(resendCooldown: resendCooldownSeconds));
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final left = state.resendCooldown - 1;
      if (left <= 0) timer.cancel();
      // A tick must not clear an error the user hasn't read yet.
      emit(state.copyWith(resendCooldown: left, keepFailure: true));
    });
  }

  @override
  Future<void> close() {
    _cooldownTimer?.cancel();
    return super.close();
  }
}
