part of 'login_cubit.dart';

enum LoginStatus {
  editing,
  submitting,
  success,
  failure;

  bool get isBusy => this == submitting || this == success;
}

final class LoginState extends Equatable {
  const LoginState({
    this.email = const Email.pure(),
    this.password = const Password.pure(),
    this.status = LoginStatus.editing,
    this.failure,
  });

  final Email email;
  final Password password;
  final LoginStatus status;
  final Failure? failure;

  /// The Login button is enabled once both fields have text. Full
  /// validation runs on submit, so errors don't appear while typing.
  bool get canSubmit =>
      email.value.trim().isNotEmpty && password.value.isNotEmpty;

  /// [failure] is cleared unless passed explicitly, so editing a field
  /// dismisses the previous error.
  LoginState copyWith({
    Email? email,
    Password? password,
    LoginStatus? status,
    Failure? failure,
  }) => LoginState(
    email: email ?? this.email,
    password: password ?? this.password,
    status: status ?? this.status,
    failure: failure,
  );

  @override
  List<Object?> get props => [email, password, status, failure];
}
