part of 'password_reset_cubit.dart';

enum PasswordResetStep {
  /// Enter the account email.
  email,

  /// Code dialog open.
  code,

  /// Code accepted; "Verification Successful" dialog.
  verified,

  /// Set a new password.
  newPassword,

  /// Password changed; "Password Reset Successful" dialog.
  done,
}

final class PasswordResetState extends Equatable {
  const PasswordResetState({
    this.step = PasswordResetStep.email,
    this.email = const Email.pure(),
    this.code = const OtpCode.pure(),
    this.password = const Password.pure(),
    this.confirmation = const ConfirmedPassword.pure(),
    this.isSubmitting = false,
    this.resendCooldown = 0,
    this.resetToken,
    this.failure,
  });

  final PasswordResetStep step;
  final Email email;
  final OtpCode code;
  final Password password;
  final ConfirmedPassword confirmation;
  final bool isSubmitting;

  /// Seconds until "Resend OTP" is available again.
  final int resendCooldown;

  /// Single-use token from a verified code. Needed to set the new password.
  final String? resetToken;
  final Failure? failure;

  bool get canSendCode => email.value.trim().isNotEmpty;
  bool get canVerify => code.isValid;
  bool get canReset =>
      password.value.isNotEmpty && confirmation.value.isNotEmpty;

  /// [failure] is cleared unless passed or [keepFailure] is set, so the next
  /// user action dismisses the previous error.
  PasswordResetState copyWith({
    PasswordResetStep? step,
    Email? email,
    OtpCode? code,
    Password? password,
    ConfirmedPassword? confirmation,
    bool? isSubmitting,
    int? resendCooldown,
    String? resetToken,
    Failure? failure,
    bool keepFailure = false,
  }) => PasswordResetState(
    step: step ?? this.step,
    email: email ?? this.email,
    code: code ?? this.code,
    password: password ?? this.password,
    confirmation: confirmation ?? this.confirmation,
    isSubmitting: isSubmitting ?? this.isSubmitting,
    resendCooldown: resendCooldown ?? this.resendCooldown,
    resetToken: resetToken ?? this.resetToken,
    failure: keepFailure ? this.failure : failure,
  );

  @override
  List<Object?> get props => [
    step,
    email,
    code,
    password,
    confirmation,
    isSubmitting,
    resendCooldown,
    resetToken,
    failure,
  ];

  /// Keeps passwords, codes and the reset token out of logs and test output.
  @override
  String toString() =>
      'PasswordResetState($step, submitting: $isSubmitting, '
      'cooldown: $resendCooldown, failure: $failure)';
}
